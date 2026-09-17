import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/performance_rating.dart';
import '../../domain/entities/exam_attempt_entity.dart';
import '../../domain/entities/local_attempt_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/quiz_entity.dart';
import '../../domain/repositories/quiz_repository.dart';

// EVENTS
abstract class ExamRunnerEvent extends Equatable {
  const ExamRunnerEvent();
  @override
  List<Object?> get props => [];
}

class StartExamEvent extends ExamRunnerEvent {
  final String quizId;
  final String studentId;
  final String? startCode;

  const StartExamEvent({
    required this.quizId,
    required this.studentId,
    this.startCode,
  });

  @override
  List<Object?> get props => [quizId, studentId, startCode];
}

class SelectAnswerEvent extends ExamRunnerEvent {
  final String questionId;
  final int optionIndex;
  const SelectAnswerEvent({
    required this.questionId,
    required this.optionIndex,
  });
  @override
  List<Object?> get props => [questionId, optionIndex];
}

class GoToQuestionEvent extends ExamRunnerEvent {
  final int index;
  const GoToQuestionEvent(this.index);
  @override
  List<Object?> get props => [index];
}

class TimerTickEvent extends ExamRunnerEvent {
  final int remainingSeconds;
  const TimerTickEvent(this.remainingSeconds);
  @override
  List<Object?> get props => [remainingSeconds];
}

class SubmitExamEvent extends ExamRunnerEvent {
  final bool isAutoSubmit;
  const SubmitExamEvent({this.isAutoSubmit = false});
  @override
  List<Object?> get props => [isAutoSubmit];
}

class RetrySyncEvent extends ExamRunnerEvent {
  final String attemptId;
  const RetrySyncEvent(this.attemptId);
  @override
  List<Object?> get props => [attemptId];
}

// STATES
abstract class ExamRunnerState extends Equatable {
  const ExamRunnerState();
  @override
  List<Object?> get props => [];
}

class ExamRunnerInitial extends ExamRunnerState {}

class ExamRunnerLoading extends ExamRunnerState {}

class ExamInProgressState extends ExamRunnerState {
  final String attemptId;
  final QuizEntity quiz;
  final String studentId;
  final List<QuestionEntity> questions;
  final int currentQuestionIndex;
  final Map<String, int> selectedAnswers;
  final int remainingSeconds;
  final DateTime startedAt;
  final DateTime deadline;
  final bool isSubmitting;
  final bool isResumedFromDraft;

  const ExamInProgressState({
    required this.attemptId,
    required this.quiz,
    required this.studentId,
    required this.questions,
    this.currentQuestionIndex = 0,
    required this.selectedAnswers,
    required this.remainingSeconds,
    required this.startedAt,
    required this.deadline,
    this.isSubmitting = false,
    this.isResumedFromDraft = false,
  });

  QuestionEntity get currentQuestion => questions[currentQuestionIndex];
  bool get isLastQuestion => currentQuestionIndex == questions.length - 1;
  int get answeredCount => selectedAnswers.length;

  ExamInProgressState copyWith({
    String? attemptId,
    QuizEntity? quiz,
    String? studentId,
    List<QuestionEntity>? questions,
    int? currentQuestionIndex,
    Map<String, int>? selectedAnswers,
    int? remainingSeconds,
    DateTime? startedAt,
    DateTime? deadline,
    bool? isSubmitting,
    bool? isResumedFromDraft,
  }) {
    return ExamInProgressState(
      attemptId: attemptId ?? this.attemptId,
      quiz: quiz ?? this.quiz,
      studentId: studentId ?? this.studentId,
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      startedAt: startedAt ?? this.startedAt,
      deadline: deadline ?? this.deadline,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isResumedFromDraft: isResumedFromDraft ?? this.isResumedFromDraft,
    );
  }

  @override
  List<Object?> get props => [
    attemptId,
    quiz,
    studentId,
    questions,
    currentQuestionIndex,
    selectedAnswers,
    remainingSeconds,
    startedAt,
    deadline,
    isSubmitting,
    isResumedFromDraft,
  ];
}

class ExamSubmittedSuccessState extends ExamRunnerState {
  final ExamAttemptEntity attempt;
  final QuizEntity quiz;
  final bool wasAutoSubmitted;
  final bool isSyncing;

  const ExamSubmittedSuccessState({
    required this.attempt,
    required this.quiz,
    this.wasAutoSubmitted = false,
    this.isSyncing = false,
  });

  ExamSubmittedSuccessState copyWith({
    ExamAttemptEntity? attempt,
    QuizEntity? quiz,
    bool? wasAutoSubmitted,
    bool? isSyncing,
  }) {
    return ExamSubmittedSuccessState(
      attempt: attempt ?? this.attempt,
      quiz: quiz ?? this.quiz,
      wasAutoSubmitted: wasAutoSubmitted ?? this.wasAutoSubmitted,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  List<Object?> get props => [attempt, quiz, wasAutoSubmitted, isSyncing];
}

class ExamRunnerErrorState extends ExamRunnerState {
  final String message;
  const ExamRunnerErrorState(this.message);
  @override
  List<Object?> get props => [message];
}

// BLOC
class ExamRunnerBloc extends Bloc<ExamRunnerEvent, ExamRunnerState> {
  final QuizRepository _quizRepository;
  Timer? _timer;

  ExamRunnerBloc(this._quizRepository) : super(ExamRunnerInitial()) {
    on<StartExamEvent>(_onStartExam);
    on<SelectAnswerEvent>(_onSelectAnswer);
    on<GoToQuestionEvent>(_onGoToQuestion);
    on<TimerTickEvent>(_onTimerTick);
    on<SubmitExamEvent>(_onSubmitExam);
    on<RetrySyncEvent>(_onRetrySync);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  Future<void> _onStartExam(
    StartExamEvent event,
    Emitter<ExamRunnerState> emit,
  ) async {
    emit(ExamRunnerLoading());
    try {
      final quiz = await _quizRepository.getQuizById(event.quizId);
      if (quiz == null) {
        emit(const ExamRunnerErrorState('تعذر تحميل بيانات الاختبار.'));
        return;
      }

      if (!quiz.isAvailableNow) {
        emit(
          const ExamRunnerErrorState('هذا الاختبار غير متاح في الوقت الحالي.'),
        );
        return;
      }

      // Check if there is an active local attempt already in progress (Crash / Restart recovery)
      final existingAttempt = await _quizRepository.loadActiveAttemptLocally(
        event.quizId,
        event.studentId,
      );

      if (existingAttempt != null &&
          existingAttempt.status == AttemptSyncStatus.inProgress) {
        // RESUME THE SAME ATTEMPT
        final remaining = existingAttempt.remainingSeconds;

        if (existingAttempt.isExpired || remaining <= 0) {
          // Timer expired while student was away! Auto-submit locally immediately.
          await _autoSubmitLocalAttempt(existingAttempt, quiz, emit);
          return;
        }

        List<QuestionEntity> questions = List.from(quiz.questions);
        if (quiz.shuffleQuestions) {
          questions.shuffle();
        }

        emit(
          ExamInProgressState(
            attemptId: existingAttempt.attemptId,
            quiz: quiz,
            studentId: event.studentId,
            questions: questions,
            selectedAnswers: existingAttempt.answers,
            remainingSeconds: remaining,
            startedAt: existingAttempt.startedAt,
            deadline: existingAttempt.deadline,
            isResumedFromDraft: true,
          ),
        );

        _startPersistentTimer(existingAttempt.deadline);
        return;
      }

      // NEW ATTEMPT CREATION:
      // 1. Check Start Code if required
      if (quiz.requireStartCode) {
        final code = event.startCode ?? '';
        if (!quiz.validateStartCode(code)) {
          emit(
            const ExamRunnerErrorState(
              'رمز بدء الاختبار غير صحيح. يرجى مراجعة المعلم.',
            ),
          );
          return;
        }
      }

      // 2. Check if student already passed or consumed max attempts
      final pastAttempts = await _quizRepository.getAttemptsForStudent(
        event.studentId,
        courseId: quiz.courseId,
      );
      final examAttempts =
          pastAttempts.where((a) => a.examId == event.quizId).toList();
      final hasPassed = examAttempts.any(
        (a) => PerformanceRating.fromPercentage(a.percentage).isSuccessful,
      );
      if (hasPassed || examAttempts.length >= quiz.maxAttempts) {
        emit(
          ExamRunnerErrorState(
            hasPassed
                ? 'تم اجتياز هذا الاختبار بنجاح مسبقاً.'
                : 'تم استنفاد المحاولات المسموح بها لهذا الاختبار (${examAttempts.length}/${quiz.maxAttempts}).',
          ),
        );
        return;
      }

      // 3. Question shuffling
      List<QuestionEntity> questions = List.from(quiz.questions);
      if (quiz.shuffleQuestions) {
        questions.shuffle();
      }

      // 4. Create local attempt with stable UUID v4 and timestamp deadline
      final now = DateTime.now();
      final deadline = now.add(Duration(minutes: quiz.durationMinutes));
      final stableAttemptId = const Uuid().v4();

      final newAttempt = LocalAttemptEntity(
        attemptId: stableAttemptId,
        studentId: event.studentId,
        quizId: quiz.id,
        courseId: quiz.courseId,
        attemptNumber: examAttempts.length + 1,
        startedAt: now,
        deadline: deadline,
        answers: const {},
        status: AttemptSyncStatus.inProgress,
      );

      // Save locally immediately
      await _quizRepository.saveActiveAttemptLocally(newAttempt);

      final totalSeconds = quiz.durationMinutes * 60;

      emit(
        ExamInProgressState(
          attemptId: stableAttemptId,
          quiz: quiz,
          studentId: event.studentId,
          questions: questions,
          selectedAnswers: const {},
          remainingSeconds: totalSeconds,
          startedAt: now,
          deadline: deadline,
          isResumedFromDraft: false,
        ),
      );

      _startPersistentTimer(deadline);
    } catch (e) {
      emit(ExamRunnerErrorState('حدث خطأ أثناء تهيئة الاختبار: $e'));
    }
  }

  void _startPersistentTimer(DateTime deadline) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        add(TimerTickEvent(remaining));
      } else {
        t.cancel();
        add(const SubmitExamEvent(isAutoSubmit: true));
      }
    });
  }

  void _onTimerTick(TimerTickEvent event, Emitter<ExamRunnerState> emit) {
    if (state is ExamInProgressState) {
      final current = state as ExamInProgressState;
      emit(current.copyWith(remainingSeconds: event.remainingSeconds));
    }
  }

  void _onSelectAnswer(SelectAnswerEvent event, Emitter<ExamRunnerState> emit) {
    if (state is ExamInProgressState) {
      final current = state as ExamInProgressState;
      final updatedAnswers = Map<String, int>.from(current.selectedAnswers);
      updatedAnswers[event.questionId] = event.optionIndex;

      emit(current.copyWith(selectedAnswers: updatedAnswers));

      // Local Answer Persistence (Zero network cost)
      final updatedAttempt = LocalAttemptEntity(
        attemptId: current.attemptId,
        studentId: current.studentId,
        quizId: current.quiz.id,
        courseId: current.quiz.courseId,
        startedAt: current.startedAt,
        deadline: current.deadline,
        answers: updatedAnswers,
        status: AttemptSyncStatus.inProgress,
      );

      _quizRepository.saveActiveAttemptLocally(updatedAttempt);
    }
  }

  void _onGoToQuestion(GoToQuestionEvent event, Emitter<ExamRunnerState> emit) {
    if (state is ExamInProgressState) {
      final current = state as ExamInProgressState;
      if (event.index >= 0 && event.index < current.questions.length) {
        emit(current.copyWith(currentQuestionIndex: event.index));
      }
    }
  }

  Future<void> _onSubmitExam(
    SubmitExamEvent event,
    Emitter<ExamRunnerState> emit,
  ) async {
    if (state is ExamInProgressState) {
      final current = state as ExamInProgressState;
      _timer?.cancel();
      emit(current.copyWith(isSubmitting: true));

      try {
        final submissionTime = DateTime.now();
        final durationUsed =
            submissionTime.difference(current.startedAt).inSeconds;

        int correctCount = 0;
        int totalScore = 0;

        for (final q in current.questions) {
          final selected = current.selectedAnswers[q.id];
          if (selected != null && selected == q.correctAnswerIndex) {
            correctCount++;
            totalScore += q.marks;
          }
        }

        final incorrectCount = current.questions.length - correctCount;
        final maxMarks =
            current.quiz.totalMarks > 0
                ? current.quiz.totalMarks
                : current.questions.fold<int>(0, (sum, q) => sum + q.marks);

        final percentage = maxMarks > 0 ? (totalScore / maxMarks) * 100.0 : 0.0;
        final isPassed = QuizEntity.calculateIsPassed(
          score: totalScore,
          totalMarks: maxMarks,
          passingScore: current.quiz.passingScore,
        );

        // Fetch past attempts to maintain accurate attempt number
        final pastAttempts = await _quizRepository.getAttemptsForStudent(
          current.studentId,
          courseId: current.quiz.courseId,
        );
        final attemptCount =
            pastAttempts.where((a) => a.examId == current.quiz.id).length;

        // Construct completed local attempt marked completedPendingSync
        final completedAttempt = LocalAttemptEntity(
          attemptId: current.attemptId,
          studentId: current.studentId,
          quizId: current.quiz.id,
          courseId: current.quiz.courseId,
          attemptNumber: attemptCount + 1,
          startedAt: current.startedAt,
          deadline: current.deadline,
          submittedAt: submissionTime,
          durationSecondsUsed: durationUsed > 0 ? durationUsed : 1,
          answers: current.selectedAnswers,
          correctCount: correctCount,
          incorrectCount: incorrectCount,
          score: totalScore,
          totalMarks: maxMarks,
          percentage: double.parse(percentage.toStringAsFixed(1)),
          isPassed: isPassed,
          status: AttemptSyncStatus.completedPendingSync,
        );

        // ALWAYS SAVE LOCALLY FIRST
        await _quizRepository.saveCompletedAttemptLocally(completedAttempt);

        // Clear in-progress draft
        await _quizRepository.clearActiveAttemptLocally(
          current.quiz.id,
          current.studentId,
        );

        // Emit local submission success immediately
        final examAttemptEntity = completedAttempt.toExamAttemptEntity();
        emit(
          ExamSubmittedSuccessState(
            attempt: examAttemptEntity,
            quiz: current.quiz,
            wasAutoSubmitted: event.isAutoSubmit,
            isSyncing: true,
          ),
        );

        // Background idempotent synchronization to Firestore
        _triggerBackgroundSync(completedAttempt, current.quiz, emit);
      } catch (e) {
        emit(ExamRunnerErrorState('فشل تسليم الاختبار محلياً: $e'));
      }
    }
  }

  Future<void> _autoSubmitLocalAttempt(
    LocalAttemptEntity attempt,
    QuizEntity quiz,
    Emitter<ExamRunnerState> emit,
  ) async {
    final submissionTime = DateTime.now();
    int correctCount = 0;
    int totalScore = 0;

    for (final q in quiz.questions) {
      final selected = attempt.answers[q.id];
      if (selected != null && selected == q.correctAnswerIndex) {
        correctCount++;
        totalScore += q.marks;
      }
    }

    final incorrectCount = quiz.questions.length - correctCount;
    final maxMarks =
        quiz.totalMarks > 0
            ? quiz.totalMarks
            : quiz.questions.fold<int>(0, (sum, q) => sum + q.marks);

    final percentage = maxMarks > 0 ? (totalScore / maxMarks) * 100.0 : 0.0;
    final isPassed = QuizEntity.calculateIsPassed(
      score: totalScore,
      totalMarks: maxMarks,
      passingScore: quiz.passingScore,
    );

    final completed = attempt.copyWith(
      submittedAt: submissionTime,
      durationSecondsUsed: quiz.durationMinutes * 60,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      score: totalScore,
      totalMarks: maxMarks,
      percentage: double.parse(percentage.toStringAsFixed(1)),
      isPassed: isPassed,
      status: AttemptSyncStatus.completedPendingSync,
    );

    await _quizRepository.saveCompletedAttemptLocally(completed);
    await _quizRepository.clearActiveAttemptLocally(quiz.id, attempt.studentId);

    final examAttempt = completed.toExamAttemptEntity();
    emit(
      ExamSubmittedSuccessState(
        attempt: examAttempt,
        quiz: quiz,
        wasAutoSubmitted: true,
        isSyncing: true,
      ),
    );

    _triggerBackgroundSync(completed, quiz, emit);
  }

  void _triggerBackgroundSync(
    LocalAttemptEntity attempt,
    QuizEntity quiz,
    Emitter<ExamRunnerState> emit,
  ) {
    unawaited(() async {
      try {
        final synced = await _quizRepository.syncAttempt(attempt);
        if (!isClosed && state is ExamSubmittedSuccessState) {
          emit(
            (state as ExamSubmittedSuccessState).copyWith(
              attempt: synced.toExamAttemptEntity(),
              isSyncing: false,
            ),
          );
        }
      } catch (_) {
        if (!isClosed && state is ExamSubmittedSuccessState) {
          emit((state as ExamSubmittedSuccessState).copyWith(isSyncing: false));
        }
      }
    }());
  }

  Future<void> _onRetrySync(
    RetrySyncEvent event,
    Emitter<ExamRunnerState> emit,
  ) async {
    if (state is ExamSubmittedSuccessState) {
      final current = state as ExamSubmittedSuccessState;
      emit(current.copyWith(isSyncing: true));
      try {
        final pending = await _quizRepository.getPendingAttempts();
        final match = pending.firstWhere(
          (a) => a.attemptId == event.attemptId,
          orElse:
              () => LocalAttemptEntity(
                attemptId: current.attempt.id,
                studentId: current.attempt.studentId,
                quizId: current.attempt.examId,
                courseId: current.attempt.courseId,
                startedAt: current.attempt.startedAt,
                deadline: current.attempt.startedAt.add(
                  Duration(minutes: current.quiz.durationMinutes),
                ),
                submittedAt: current.attempt.submittedAt,
                answers: current.attempt.answers,
                correctCount: current.attempt.correctCount,
                incorrectCount: current.attempt.incorrectCount,
                score: current.attempt.score,
                percentage: current.attempt.percentage,
                isPassed: current.attempt.isPassed,
                status: AttemptSyncStatus.completedPendingSync,
              ),
        );

        final synced = await _quizRepository.syncAttempt(match);
        emit(
          current.copyWith(
            attempt: synced.toExamAttemptEntity(),
            isSyncing: false,
          ),
        );
      } catch (_) {
        emit(current.copyWith(isSyncing: false));
      }
    }
  }
}

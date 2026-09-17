import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/start_code_utils.dart';
import '../../../../core/utils/performance_rating.dart';
import 'question_entity.dart';

enum QuizType {
  quiz,
  fullExam;

  static QuizType fromString(String? val) {
    if (val?.toLowerCase() == 'fullexam' || val?.toLowerCase() == 'exam') {
      return QuizType.fullExam;
    }
    return QuizType.quiz;
  }

  String toValue() => name;
}

class QuizEntity extends Equatable {
  final String id;
  final String title;
  final String description;
  final QuizType type;
  final String courseId;
  final String? unitId;
  final String? lessonId;
  final int durationMinutes;
  final int totalMarks;
  final int passingScore;
  final int maxAttempts;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final bool showResultImmediately;
  final bool showCorrectAnswers;
  final String showExplanations; // AppConstants.explanationAfterSubmission etc.
  final bool isPublished;
  final List<QuestionEntity> questions;
  final DateTime? createdAt;
  final bool requireStartCode;
  final String? startCode; // Plain text code (teacher-side / configuration)
  final String?
  startCodeHash; // Salted SHA-256 hash for secure local student validation
  final String? startCodeSalt; // Salt used with startCodeHash

  const QuizEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.courseId,
    this.unitId,
    this.lessonId,
    this.durationMinutes = 15,
    this.totalMarks = 10,
    this.passingScore = 50,
    this.maxAttempts = 1,
    this.availableFrom,
    this.availableUntil,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.showResultImmediately = true,
    this.showCorrectAnswers = true,
    this.showExplanations = AppConstants.explanationAfterSubmission,
    this.isPublished = true,
    this.questions = const [],
    this.createdAt,
    this.requireStartCode = false,
    this.startCode,
    this.startCodeHash,
    this.startCodeSalt,
  });

  bool get isFullExam => type == QuizType.fullExam;

  bool get isAvailableNow {
    final now = DateTime.now();
    if (availableFrom != null && now.isBefore(availableFrom!)) return false;
    if (availableUntil != null && now.isAfter(availableUntil!)) return false;
    return true;
  }

  bool get canShowExplanationsNow {
    if (showExplanations == AppConstants.explanationNever) return false;
    if (showExplanations == AppConstants.explanationAfterSubmission)
      return true;
    if (showExplanations == AppConstants.explanationAfterExamEnds) {
      if (availableUntil == null) return true;
      return DateTime.now().isAfter(availableUntil!);
    }
    return false;
  }

  /// Completely offline start-code validation using stored secure hash, salt, or plain code.
  /// Operates 100% offline with zero network dependency.
  bool validateStartCode(String enteredCode) {
    if (!requireStartCode) return true;
    final cleanInput = enteredCode.trim();
    if (cleanInput.isEmpty) return false;

    // 1. Direct match with plain start code if present
    if (startCode != null && startCode!.trim().isNotEmpty) {
      if (cleanInput == startCode!.trim()) {
        return true;
      }
    }

    // 2. Cryptographic salted hash verification if hash is present
    final hash = startCodeHash;
    final salt = startCodeSalt;
    if (hash != null && hash.isNotEmpty) {
      return StartCodeUtils.verifyStartCode(
        inputCode: cleanInput,
        expectedHash: hash,
        salt: salt ?? '',
      );
    }

    return false;
  }


  QuizEntity copyWith({
    String? id,
    String? title,
    String? description,
    QuizType? type,
    String? courseId,
    String? unitId,
    String? lessonId,
    int? durationMinutes,
    int? totalMarks,
    int? passingScore,
    int? maxAttempts,
    DateTime? availableFrom,
    DateTime? availableUntil,
    bool? shuffleQuestions,
    bool? shuffleOptions,
    bool? showResultImmediately,
    bool? showCorrectAnswers,
    String? showExplanations,
    bool? isPublished,
    List<QuestionEntity>? questions,
    DateTime? createdAt,
    bool? requireStartCode,
    String? startCode,
    String? startCodeHash,
    String? startCodeSalt,
  }) {
    return QuizEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      courseId: courseId ?? this.courseId,
      unitId: unitId ?? this.unitId,
      lessonId: lessonId ?? this.lessonId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      totalMarks: totalMarks ?? this.totalMarks,
      passingScore: passingScore ?? this.passingScore,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      shuffleOptions: shuffleOptions ?? this.shuffleOptions,
      showResultImmediately:
          showResultImmediately ?? this.showResultImmediately,
      showCorrectAnswers: showCorrectAnswers ?? this.showCorrectAnswers,
      showExplanations: showExplanations ?? this.showExplanations,
      isPublished: isPublished ?? this.isPublished,
      questions: questions ?? this.questions,
      createdAt: createdAt ?? this.createdAt,
      requireStartCode: requireStartCode ?? this.requireStartCode,
      startCode: startCode ?? this.startCode,
      startCodeHash: startCodeHash ?? this.startCodeHash,
      startCodeSalt: startCodeSalt ?? this.startCodeSalt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    type,
    courseId,
    unitId,
    lessonId,
    durationMinutes,
    totalMarks,
    passingScore,
    maxAttempts,
    availableFrom,
    availableUntil,
    shuffleQuestions,
    shuffleOptions,
    showResultImmediately,
    showCorrectAnswers,
    showExplanations,
    isPublished,
    questions,
    createdAt,
    requireStartCode,
    startCode,
    startCodeHash,
    startCodeSalt,
  ];

  /// Uses the platform-wide percentage policy. [passingScore] remains in the
  /// signature for stored-data compatibility, but ambiguous raw-mark values no
  /// longer change the result.
  static bool calculateIsPassed({
    required int score,
    required int totalMarks,
    required int passingScore,
  }) {
    return PerformanceRating.fromScore(
      score: score,
      totalMarks: totalMarks,
    ).isSuccessful;
  }
}

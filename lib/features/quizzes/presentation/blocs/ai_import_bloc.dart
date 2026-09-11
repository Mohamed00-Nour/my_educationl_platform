import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ai_import_item.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../../domain/usecases/validate_ai_questions_usecase.dart';

// EVENTS
abstract class AIImportEvent extends Equatable {
  const AIImportEvent();
  @override
  List<Object?> get props => [];
}

class ParseAndValidateRawInputEvent extends AIImportEvent {
  final String rawInput;
  const ParseAndValidateRawInputEvent(this.rawInput);
  @override
  List<Object?> get props => [rawInput];
}

class UpdateImportedQuestionEvent extends AIImportEvent {
  final int itemIndex;
  final QuestionEntity updatedQuestion;
  const UpdateImportedQuestionEvent(this.itemIndex, this.updatedQuestion);
  @override
  List<Object?> get props => [itemIndex, updatedQuestion];
}

class DeleteImportedQuestionEvent extends AIImportEvent {
  final int itemIndex;
  const DeleteImportedQuestionEvent(this.itemIndex);
  @override
  List<Object?> get props => [itemIndex];
}

class SaveToQuestionBankEvent extends AIImportEvent {
  final String? courseId;
  const SaveToQuestionBankEvent({this.courseId});
  @override
  List<Object?> get props => [courseId];
}

// STATES
abstract class AIImportState extends Equatable {
  const AIImportState();
  @override
  List<Object?> get props => [];
}

class AIImportInitial extends AIImportState {}

class AIImportLoading extends AIImportState {}

class AIImportPreviewState extends AIImportState {
  final AIImportSummary summary;
  final String activeFilter; // 'all', 'valid', 'errors'

  const AIImportPreviewState({
    required this.summary,
    this.activeFilter = 'all',
  });

  List<AIImportItem> get filteredItems {
    switch (activeFilter) {
      case 'valid':
        return summary.items.where((i) => i.isValid).toList();
      case 'errors':
        return summary.items.where((i) => !i.isValid).toList();
      case 'all':
      default:
        return summary.items;
    }
  }

  AIImportPreviewState copyWith({
    AIImportSummary? summary,
    String? activeFilter,
  }) {
    return AIImportPreviewState(
      summary: summary ?? this.summary,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  @override
  List<Object?> get props => [summary, activeFilter];
}

class AIImportSavedToBankSuccess extends AIImportState {
  final int count;
  const AIImportSavedToBankSuccess(this.count);
  @override
  List<Object?> get props => [count];
}

class AIImportErrorState extends AIImportState {
  final String message;
  const AIImportErrorState(this.message);
  @override
  List<Object?> get props => [message];
}

// BLOC
class AIImportBloc extends Bloc<AIImportEvent, AIImportState> {
  final ValidateAIQuestionsUseCase _validateUseCase;
  final QuizRepository _quizRepository;

  AIImportBloc({
    required ValidateAIQuestionsUseCase validateUseCase,
    required QuizRepository quizRepository,
  }) : _validateUseCase = validateUseCase,
       _quizRepository = quizRepository,
       super(AIImportInitial()) {
    on<ParseAndValidateRawInputEvent>(_onParseAndValidate);
    on<UpdateImportedQuestionEvent>(_onUpdateQuestion);
    on<DeleteImportedQuestionEvent>(_onDeleteQuestion);
    on<SaveToQuestionBankEvent>(_onSaveToBank);
  }

  void _onParseAndValidate(
    ParseAndValidateRawInputEvent event,
    Emitter<AIImportState> emit,
  ) {
    emit(AIImportLoading());
    try {
      final summary = _validateUseCase.execute(event.rawInput);
      emit(AIImportPreviewState(summary: summary));
    } catch (e) {
      emit(AIImportErrorState('Failed to parse question input: $e'));
    }
  }

  void _onUpdateQuestion(
    UpdateImportedQuestionEvent event,
    Emitter<AIImportState> emit,
  ) {
    if (state is AIImportPreviewState) {
      final current = state as AIImportPreviewState;
      final updatedList = List<AIImportItem>.from(current.summary.items);

      final idx = updatedList.indexWhere((it) => it.index == event.itemIndex);
      if (idx != -1) {
        // Re-validate updated question
        final q = event.updatedQuestion;
        final List<String> errors = [];
        if (q.questionText.trim().isEmpty)
          errors.add('Question text cannot be empty');
        if (q.isMcq && q.options.length < 2)
          errors.add('Multiple choice must have at least 2 options');
        if (q.correctAnswerIndex < 0 ||
            q.correctAnswerIndex >= q.options.length) {
          errors.add('Valid correct answer must be selected');
        }

        updatedList[idx] = updatedList[idx].copyWith(
          question: q,
          isValid: errors.isEmpty,
          errors: errors,
        );

        final validCount = updatedList.where((it) => it.isValid).length;
        final newSummary = AIImportSummary(
          totalDetected: updatedList.length,
          validCount: validCount,
          needsReviewCount: updatedList.length - validCount,
          items: updatedList,
        );

        emit(current.copyWith(summary: newSummary));
      }
    }
  }

  void _onDeleteQuestion(
    DeleteImportedQuestionEvent event,
    Emitter<AIImportState> emit,
  ) {
    if (state is AIImportPreviewState) {
      final current = state as AIImportPreviewState;
      final updatedList =
          current.summary.items
              .where((it) => it.index != event.itemIndex)
              .toList();

      final validCount = updatedList.where((it) => it.isValid).length;
      final newSummary = AIImportSummary(
        totalDetected: updatedList.length,
        validCount: validCount,
        needsReviewCount: updatedList.length - validCount,
        items: updatedList,
      );

      emit(current.copyWith(summary: newSummary));
    }
  }

  Future<void> _onSaveToBank(
    SaveToQuestionBankEvent event,
    Emitter<AIImportState> emit,
  ) async {
    if (state is AIImportPreviewState) {
      final current = state as AIImportPreviewState;
      final validQuestions =
          current.summary.items
              .where((it) => it.isValid)
              .map((it) => it.question.copyWith(courseId: event.courseId))
              .toList();

      if (validQuestions.isEmpty) {
        emit(const AIImportErrorState('No valid questions available to save.'));
        return;
      }

      emit(AIImportLoading());
      try {
        await _quizRepository.saveQuestionsToBank(validQuestions);
        emit(AIImportSavedToBankSuccess(validQuestions.length));
      } catch (e) {
        emit(AIImportErrorState('Failed to save to Question Bank: $e'));
      }
    }
  }
}

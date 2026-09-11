import 'package:equatable/equatable.dart';
import 'question_entity.dart';

class AIImportItem extends Equatable {
  final int index;
  final QuestionEntity question;
  final bool isValid;
  final List<String> errors;
  final bool isDuplicate;

  const AIImportItem({
    required this.index,
    required this.question,
    required this.isValid,
    this.errors = const [],
    this.isDuplicate = false,
  });

  AIImportItem copyWith({
    int? index,
    QuestionEntity? question,
    bool? isValid,
    List<String>? errors,
    bool? isDuplicate,
  }) {
    return AIImportItem(
      index: index ?? this.index,
      question: question ?? this.question,
      isValid: isValid ?? this.isValid,
      errors: errors ?? this.errors,
      isDuplicate: isDuplicate ?? this.isDuplicate,
    );
  }

  @override
  List<Object?> get props => [index, question, isValid, errors, isDuplicate];
}

class AIImportSummary extends Equatable {
  final int totalDetected;
  final int validCount;
  final int needsReviewCount;
  final List<AIImportItem> items;

  const AIImportSummary({
    required this.totalDetected,
    required this.validCount,
    required this.needsReviewCount,
    required this.items,
  });

  bool get hasErrors => needsReviewCount > 0;
  bool get canPublish => validCount > 0 && needsReviewCount == 0;

  @override
  List<Object?> get props => [
    totalDetected,
    validCount,
    needsReviewCount,
    items,
  ];
}

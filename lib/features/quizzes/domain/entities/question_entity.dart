import 'package:equatable/equatable.dart';

class QuestionEntity extends Equatable {
  final String id;
  final String type; // 'mcq' or 'trueFalse'
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final int marks;
  final String difficulty; // 'easy', 'medium', 'hard'
  final String? topic;
  final String? courseId;
  final String? unitId;
  final String? lessonId;

  const QuestionEntity({
    required this.id,
    required this.type,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation = '',
    this.marks = 1,
    this.difficulty = 'medium',
    this.topic,
    this.courseId,
    this.unitId,
    this.lessonId,
  });

  bool get isMcq => type.toLowerCase() == 'mcq';
  bool get isTrueFalse =>
      type.toLowerCase() == 'truefalse' || type.toLowerCase() == 'tf';

  QuestionEntity copyWith({
    String? id,
    String? type,
    String? questionText,
    List<String>? options,
    int? correctAnswerIndex,
    String? explanation,
    int? marks,
    String? difficulty,
    String? topic,
    String? courseId,
    String? unitId,
    String? lessonId,
  }) {
    return QuestionEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      explanation: explanation ?? this.explanation,
      marks: marks ?? this.marks,
      difficulty: difficulty ?? this.difficulty,
      topic: topic ?? this.topic,
      courseId: courseId ?? this.courseId,
      unitId: unitId ?? this.unitId,
      lessonId: lessonId ?? this.lessonId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    questionText,
    options,
    correctAnswerIndex,
    explanation,
    marks,
    difficulty,
    topic,
    courseId,
    unitId,
    lessonId,
  ];
}

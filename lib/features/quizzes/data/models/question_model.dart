import '../../domain/entities/question_entity.dart';

class QuestionModel extends QuestionEntity {
  const QuestionModel({
    required super.id,
    required super.type,
    required super.questionText,
    required super.options,
    required super.correctAnswerIndex,
    super.explanation,
    super.marks,
    super.difficulty,
    super.topic,
    super.courseId,
    super.unitId,
    super.lessonId,
  });

  factory QuestionModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return QuestionModel(
      id: id ?? map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'mcq',
      questionText: (map['questionText'] ?? map['question'] ?? '').toString(),
      options:
          (map['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctAnswerIndex:
          (map['correctAnswerIndex'] ?? map['correctAnswer'] as num?)
              ?.toInt() ??
          0,
      explanation: map['explanation']?.toString() ?? '',
      marks: (map['marks'] as num?)?.toInt() ?? 1,
      difficulty: map['difficulty']?.toString() ?? 'medium',
      topic: map['topic']?.toString(),
      courseId: map['courseId']?.toString(),
      unitId: map['unitId']?.toString(),
      lessonId: map['lessonId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'marks': marks,
      'difficulty': difficulty,
      'topic': topic,
      'courseId': courseId,
      'unitId': unitId,
      'lessonId': lessonId,
    };
  }

  factory QuestionModel.fromEntity(QuestionEntity entity) {
    return QuestionModel(
      id: entity.id,
      type: entity.type,
      questionText: entity.questionText,
      options: entity.options,
      correctAnswerIndex: entity.correctAnswerIndex,
      explanation: entity.explanation,
      marks: entity.marks,
      difficulty: entity.difficulty,
      topic: entity.topic,
      courseId: entity.courseId,
      unitId: entity.unitId,
      lessonId: entity.lessonId,
    );
  }
}

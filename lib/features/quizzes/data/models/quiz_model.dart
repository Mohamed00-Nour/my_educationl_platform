import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/start_code_utils.dart';
import '../../domain/entities/quiz_entity.dart';
import 'question_model.dart';

class QuizModel extends QuizEntity {
  const QuizModel({
    required super.id,
    required super.title,
    required super.description,
    required super.type,
    required super.courseId,
    super.unitId,
    super.lessonId,
    super.durationMinutes,
    super.totalMarks,
    super.passingScore,
    super.maxAttempts,
    super.availableFrom,
    super.availableUntil,
    super.shuffleQuestions,
    super.shuffleOptions,
    super.showResultImmediately,
    super.showCorrectAnswers,
    super.showExplanations,
    super.isPublished,
    super.questions,
    super.createdAt,
    super.requireStartCode,
    super.startCode,
    super.startCodeHash,
    super.startCodeSalt,
  });

  factory QuizModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return QuizModel.fromMap(data, id: doc.id);
  }

  factory QuizModel.fromMap(Map<String, dynamic> data, {String? id}) {
    final rawQuestions = data['questions'] as List<dynamic>? ?? [];

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    final rawStartCode = data['startCode']?.toString() ??
        data['start_code']?.toString() ??
        data['code']?.toString() ??
        data['startCodePlain']?.toString();

    final hasCodeString = rawStartCode != null && rawStartCode.trim().isNotEmpty;

    final rawRequireStartCode = (data['requireStartCode'] as bool?) ??
        (data['require_start_code'] as bool?) ??
        (data['hasStartCode'] as bool?) ??
        hasCodeString;

    String? hash = data['startCodeHash']?.toString() ??
        data['start_code_hash']?.toString();
    String? salt = data['startCodeSalt']?.toString() ??
        data['start_code_salt']?.toString();

    if (hasCodeString) {
      if (hash == null || hash.isEmpty || salt == null || salt.isEmpty) {
        salt = StartCodeUtils.generateSalt();
        hash = StartCodeUtils.hashStartCode(rawStartCode.trim(), salt);
      }
    }

    return QuizModel(
      id: id ?? data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      type: QuizType.fromString(data['type']?.toString()),
      courseId: data['courseId']?.toString() ?? '',
      unitId: data['unitId']?.toString(),
      lessonId: data['lessonId']?.toString(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 15,
      totalMarks: (data['totalMarks'] as num?)?.toInt() ?? 10,
      passingScore: (data['passingScore'] as num?)?.toInt() ?? 50,
      maxAttempts: (data['maxAttempts'] as num?)?.toInt() ?? 1,
      availableFrom: parseDate(data['availableFrom']),
      availableUntil: parseDate(data['availableUntil']),
      shuffleQuestions: data['shuffleQuestions'] as bool? ?? false,
      shuffleOptions: data['shuffleOptions'] as bool? ?? false,
      showResultImmediately: data['showResultImmediately'] as bool? ?? true,
      showCorrectAnswers: data['showCorrectAnswers'] as bool? ?? true,
      showExplanations:
          data['showExplanations']?.toString() ?? 'after_submission',
      isPublished: data['isPublished'] as bool? ?? true,
      questions:
          rawQuestions
              .map((q) => QuestionModel.fromMap(q as Map<String, dynamic>))
              .toList(),
      createdAt: parseDate(data['createdAt']),
      requireStartCode: rawRequireStartCode,
      startCode: rawStartCode,
      startCodeHash: hash,
      startCodeSalt: salt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type.toValue(),
      'courseId': courseId,
      'unitId': unitId,
      'lessonId': lessonId,
      'durationMinutes': durationMinutes,
      'totalMarks': totalMarks,
      'passingScore': passingScore,
      'maxAttempts': maxAttempts,
      'availableFrom':
          availableFrom != null ? Timestamp.fromDate(availableFrom!) : null,
      'availableUntil':
          availableUntil != null ? Timestamp.fromDate(availableUntil!) : null,
      'shuffleQuestions': shuffleQuestions,
      'shuffleOptions': shuffleOptions,
      'showResultImmediately': showResultImmediately,
      'showCorrectAnswers': showCorrectAnswers,
      'showExplanations': showExplanations,
      'isPublished': isPublished,
      'questions':
          questions.map((q) => QuestionModel.fromEntity(q).toMap()).toList(),
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'requireStartCode': requireStartCode,
      'startCode': startCode,
      'startCodeHash': startCodeHash,
      'startCodeSalt': startCodeSalt,
    };
  }

  /// JSON serialization for local caching without Firebase Timestamp dependency
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toValue(),
      'courseId': courseId,
      'unitId': unitId,
      'lessonId': lessonId,
      'durationMinutes': durationMinutes,
      'totalMarks': totalMarks,
      'passingScore': passingScore,
      'maxAttempts': maxAttempts,
      'availableFrom': availableFrom?.toIso8601String(),
      'availableUntil': availableUntil?.toIso8601String(),
      'shuffleQuestions': shuffleQuestions,
      'shuffleOptions': shuffleOptions,
      'showResultImmediately': showResultImmediately,
      'showCorrectAnswers': showCorrectAnswers,
      'showExplanations': showExplanations,
      'isPublished': isPublished,
      'questions':
          questions.map((q) => QuestionModel.fromEntity(q).toMap()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'requireStartCode': requireStartCode,
      'startCode': startCode,
      'startCodeHash': startCodeHash,
      'startCodeSalt': startCodeSalt,
    };
  }

  factory QuizModel.fromJson(Map<String, dynamic> json) =>
      QuizModel.fromMap(json);

  factory QuizModel.fromEntity(QuizEntity entity) {
    String? hash = entity.startCodeHash;
    String? salt = entity.startCodeSalt;
    final hasCode = entity.startCode != null && entity.startCode!.trim().isNotEmpty;

    if (hasCode) {
      if (hash == null || hash.isEmpty || salt == null || salt.isEmpty) {
        salt = StartCodeUtils.generateSalt();
        hash = StartCodeUtils.hashStartCode(entity.startCode!.trim(), salt);
      }
    }

    return QuizModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      type: entity.type,
      courseId: entity.courseId,
      unitId: entity.unitId,
      lessonId: entity.lessonId,
      durationMinutes: entity.durationMinutes,
      totalMarks: entity.totalMarks,
      passingScore: entity.passingScore,
      maxAttempts: entity.maxAttempts,
      availableFrom: entity.availableFrom,
      availableUntil: entity.availableUntil,
      shuffleQuestions: entity.shuffleQuestions,
      shuffleOptions: entity.shuffleOptions,
      showResultImmediately: entity.showResultImmediately,
      showCorrectAnswers: entity.showCorrectAnswers,
      showExplanations: entity.showExplanations,
      isPublished: entity.isPublished,
      questions: entity.questions,
      createdAt: entity.createdAt,
      requireStartCode: entity.requireStartCode || hasCode,
      startCode: entity.startCode,
      startCodeHash: hash,
      startCodeSalt: salt,
    );
  }
}

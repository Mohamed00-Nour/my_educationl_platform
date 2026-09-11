import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/exam_attempt_entity.dart';

class ExamAttemptModel extends ExamAttemptEntity {
  const ExamAttemptModel({
    required super.id,
    required super.studentId,
    required super.examId,
    required super.courseId,
    required super.startedAt,
    required super.submittedAt,
    required super.durationSecondsUsed,
    required super.answers,
    required super.correctCount,
    required super.incorrectCount,
    required super.score,
    required super.percentage,
    super.attemptNumber,
    required super.isPassed,
    super.syncStatus,
  });

  factory ExamAttemptModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawAnswers = data['answers'] as Map<String, dynamic>? ?? {};
    final Map<String, int> answersMap = {};
    rawAnswers.forEach((key, value) {
      if (value is num) answersMap[key] = value.toInt();
    });

    return ExamAttemptModel(
      id: doc.id,
      studentId: data['studentId']?.toString() ?? '',
      examId: data['examId']?.toString() ?? '',
      courseId: data['courseId']?.toString() ?? '',
      startedAt:
          (data['startedAt'] is Timestamp)
              ? (data['startedAt'] as Timestamp).toDate()
              : DateTime.now(),
      submittedAt:
          (data['submittedAt'] is Timestamp)
              ? (data['submittedAt'] as Timestamp).toDate()
              : DateTime.now(),
      durationSecondsUsed: (data['durationSecondsUsed'] as num?)?.toInt() ?? 0,
      answers: answersMap,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      incorrectCount: (data['incorrectCount'] as num?)?.toInt() ?? 0,
      score: (data['score'] as num?)?.toInt() ?? 0,
      percentage: (data['percentage'] as num?)?.toDouble() ?? 0.0,
      attemptNumber: (data['attemptNumber'] as num?)?.toInt() ?? 1,
      isPassed: data['isPassed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'examId': examId,
      'courseId': courseId,
      'startedAt': Timestamp.fromDate(startedAt),
      'submittedAt': Timestamp.fromDate(submittedAt),
      'durationSecondsUsed': durationSecondsUsed,
      'answers': answers,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'score': score,
      'percentage': percentage,
      'attemptNumber': attemptNumber,
      'isPassed': isPassed,
    };
  }

  factory ExamAttemptModel.fromEntity(ExamAttemptEntity entity) {
    return ExamAttemptModel(
      id: entity.id,
      studentId: entity.studentId,
      examId: entity.examId,
      courseId: entity.courseId,
      startedAt: entity.startedAt,
      submittedAt: entity.submittedAt,
      durationSecondsUsed: entity.durationSecondsUsed,
      answers: entity.answers,
      correctCount: entity.correctCount,
      incorrectCount: entity.incorrectCount,
      score: entity.score,
      percentage: entity.percentage,
      attemptNumber: entity.attemptNumber,
      isPassed: entity.isPassed,
      syncStatus: entity.syncStatus,
    );
  }
}

import '../../domain/entities/local_attempt_entity.dart';

class LocalAttemptModel extends LocalAttemptEntity {
  const LocalAttemptModel({
    required super.attemptId,
    required super.studentId,
    required super.quizId,
    required super.courseId,
    super.attemptNumber,
    required super.startedAt,
    required super.deadline,
    super.answers,
    super.status,
    super.submittedAt,
    super.durationSecondsUsed,
    super.correctCount,
    super.incorrectCount,
    super.score,
    super.totalMarks,
    super.percentage,
    super.isPassed,
    super.lastSyncError,
    super.lastSyncAttempt,
    super.syncRetryCount,
  });

  factory LocalAttemptModel.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? {};
    final Map<String, int> parsedAnswers = {};
    rawAnswers.forEach((k, v) {
      if (v is num) parsedAnswers[k] = v.toInt();
    });

    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? fallback;
      }
      return fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    final started = parseDate(json['startedAt'], DateTime.now());
    final deadline = parseDate(
      json['deadline'],
      started.add(const Duration(minutes: 15)),
    );

    return LocalAttemptModel(
      attemptId: json['attemptId']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      quizId: json['quizId']?.toString() ?? '',
      courseId: json['courseId']?.toString() ?? '',
      attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? 1,
      startedAt: started,
      deadline: deadline,
      answers: parsedAnswers,
      status: AttemptSyncStatus.fromString(json['status']?.toString()),
      submittedAt: parseNullableDate(json['submittedAt']),
      durationSecondsUsed: (json['durationSecondsUsed'] as num?)?.toInt(),
      correctCount: (json['correctCount'] as num?)?.toInt(),
      incorrectCount: (json['incorrectCount'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toInt(),
      totalMarks: (json['totalMarks'] as num?)?.toInt(),
      percentage: (json['percentage'] as num?)?.toDouble(),
      isPassed: json['isPassed'] as bool?,
      lastSyncError: json['lastSyncError']?.toString(),
      lastSyncAttempt: parseNullableDate(json['lastSyncAttempt']),
      syncRetryCount: (json['syncRetryCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attemptId': attemptId,
      'studentId': studentId,
      'quizId': quizId,
      'courseId': courseId,
      'attemptNumber': attemptNumber,
      'startedAt': startedAt.toIso8601String(),
      'deadline': deadline.toIso8601String(),
      'answers': answers,
      'status': status.toValue(),
      'submittedAt': submittedAt?.toIso8601String(),
      'durationSecondsUsed': durationSecondsUsed,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'score': score,
      'totalMarks': totalMarks,
      'percentage': percentage,
      'isPassed': isPassed,
      'lastSyncError': lastSyncError,
      'lastSyncAttempt': lastSyncAttempt?.toIso8601String(),
      'syncRetryCount': syncRetryCount,
    };
  }

  factory LocalAttemptModel.fromEntity(LocalAttemptEntity entity) {
    return LocalAttemptModel(
      attemptId: entity.attemptId,
      studentId: entity.studentId,
      quizId: entity.quizId,
      courseId: entity.courseId,
      attemptNumber: entity.attemptNumber,
      startedAt: entity.startedAt,
      deadline: entity.deadline,
      answers: entity.answers,
      status: entity.status,
      submittedAt: entity.submittedAt,
      durationSecondsUsed: entity.durationSecondsUsed,
      correctCount: entity.correctCount,
      incorrectCount: entity.incorrectCount,
      score: entity.score,
      totalMarks: entity.totalMarks,
      percentage: entity.percentage,
      isPassed: entity.isPassed,
      lastSyncError: entity.lastSyncError,
      lastSyncAttempt: entity.lastSyncAttempt,
      syncRetryCount: entity.syncRetryCount,
    );
  }
}

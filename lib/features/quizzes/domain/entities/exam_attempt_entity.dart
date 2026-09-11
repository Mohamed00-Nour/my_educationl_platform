import 'package:equatable/equatable.dart';
import 'local_attempt_entity.dart';

class ExamAttemptEntity extends Equatable {
  final String id;
  final String studentId;
  final String examId;
  final String courseId;
  final DateTime startedAt;
  final DateTime submittedAt;
  final int durationSecondsUsed;
  final Map<String, int> answers; // questionId -> selectedOptionIndex
  final int correctCount;
  final int incorrectCount;
  final int score;
  final double percentage;
  final int attemptNumber;
  final bool isPassed;
  final AttemptSyncStatus syncStatus;

  const ExamAttemptEntity({
    required this.id,
    required this.studentId,
    required this.examId,
    required this.courseId,
    required this.startedAt,
    required this.submittedAt,
    required this.durationSecondsUsed,
    required this.answers,
    required this.correctCount,
    required this.incorrectCount,
    required this.score,
    required this.percentage,
    this.attemptNumber = 1,
    required this.isPassed,
    this.syncStatus = AttemptSyncStatus.synced,
  });

  ExamAttemptEntity copyWith({
    String? id,
    String? studentId,
    String? examId,
    String? courseId,
    DateTime? startedAt,
    DateTime? submittedAt,
    int? durationSecondsUsed,
    Map<String, int>? answers,
    int? correctCount,
    int? incorrectCount,
    int? score,
    double? percentage,
    int? attemptNumber,
    bool? isPassed,
    AttemptSyncStatus? syncStatus,
  }) {
    return ExamAttemptEntity(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      examId: examId ?? this.examId,
      courseId: courseId ?? this.courseId,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      durationSecondsUsed: durationSecondsUsed ?? this.durationSecondsUsed,
      answers: answers ?? this.answers,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      score: score ?? this.score,
      percentage: percentage ?? this.percentage,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      isPassed: isPassed ?? this.isPassed,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  List<Object?> get props => [
    id,
    studentId,
    examId,
    courseId,
    startedAt,
    submittedAt,
    durationSecondsUsed,
    answers,
    correctCount,
    incorrectCount,
    score,
    percentage,
    attemptNumber,
    isPassed,
    syncStatus,
  ];
}

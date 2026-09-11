import 'package:equatable/equatable.dart';
import 'exam_attempt_entity.dart';

enum AttemptSyncStatus {
  inProgress,
  completedPendingSync,
  syncing,
  syncFailed,
  synced;

  static AttemptSyncStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'inprogress':
        return AttemptSyncStatus.inProgress;
      case 'completedpendingsync':
        return AttemptSyncStatus.completedPendingSync;
      case 'syncing':
        return AttemptSyncStatus.syncing;
      case 'syncfailed':
        return AttemptSyncStatus.syncFailed;
      case 'synced':
        return AttemptSyncStatus.synced;
      default:
        return AttemptSyncStatus.inProgress;
    }
  }

  String toValue() => name;
}

class LocalAttemptEntity extends Equatable {
  final String attemptId;
  final String studentId;
  final String quizId;
  final String courseId;
  final int attemptNumber;
  final DateTime startedAt;
  final DateTime deadline;
  final Map<String, int> answers; // questionId -> selectedOptionIndex
  final AttemptSyncStatus status;
  final DateTime? submittedAt;
  final int? durationSecondsUsed;
  final int? correctCount;
  final int? incorrectCount;
  final int? score;
  final int? totalMarks;
  final double? percentage;
  final bool? isPassed;
  final String? lastSyncError;
  final DateTime? lastSyncAttempt;
  final int syncRetryCount;

  const LocalAttemptEntity({
    required this.attemptId,
    required this.studentId,
    required this.quizId,
    required this.courseId,
    this.attemptNumber = 1,
    required this.startedAt,
    required this.deadline,
    this.answers = const {},
    this.status = AttemptSyncStatus.inProgress,
    this.submittedAt,
    this.durationSecondsUsed,
    this.correctCount,
    this.incorrectCount,
    this.score,
    this.totalMarks,
    this.percentage,
    this.isPassed,
    this.lastSyncError,
    this.lastSyncAttempt,
    this.syncRetryCount = 0,
  });

  /// Real-time timestamp-based remaining seconds calculation.
  /// Works completely offline, immune to in-memory reset, and survives app restarts.
  int get remainingSeconds {
    final diff = deadline.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isExpired => DateTime.now().isAfter(deadline);

  bool get isCompleted =>
      status == AttemptSyncStatus.completedPendingSync ||
      status == AttemptSyncStatus.syncing ||
      status == AttemptSyncStatus.syncFailed ||
      status == AttemptSyncStatus.synced;

  LocalAttemptEntity copyWith({
    String? attemptId,
    String? studentId,
    String? quizId,
    String? courseId,
    int? attemptNumber,
    DateTime? startedAt,
    DateTime? deadline,
    Map<String, int>? answers,
    AttemptSyncStatus? status,
    DateTime? submittedAt,
    int? durationSecondsUsed,
    int? correctCount,
    int? incorrectCount,
    int? score,
    int? totalMarks,
    double? percentage,
    bool? isPassed,
    String? lastSyncError,
    DateTime? lastSyncAttempt,
    int? syncRetryCount,
  }) {
    return LocalAttemptEntity(
      attemptId: attemptId ?? this.attemptId,
      studentId: studentId ?? this.studentId,
      quizId: quizId ?? this.quizId,
      courseId: courseId ?? this.courseId,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      startedAt: startedAt ?? this.startedAt,
      deadline: deadline ?? this.deadline,
      answers: answers ?? this.answers,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      durationSecondsUsed: durationSecondsUsed ?? this.durationSecondsUsed,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      score: score ?? this.score,
      totalMarks: totalMarks ?? this.totalMarks,
      percentage: percentage ?? this.percentage,
      isPassed: isPassed ?? this.isPassed,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
    );
  }

  /// Converts this local attempt to an [ExamAttemptEntity] to maintain
  /// 100% backward compatibility with existing downstream UI and domain consumers.
  ExamAttemptEntity toExamAttemptEntity() {
    return ExamAttemptEntity(
      id: attemptId,
      studentId: studentId,
      examId: quizId,
      courseId: courseId,
      startedAt: startedAt,
      submittedAt: submittedAt ?? DateTime.now(),
      durationSecondsUsed:
          durationSecondsUsed ??
          (submittedAt != null
              ? submittedAt!.difference(startedAt).inSeconds
              : 0),
      answers: answers,
      correctCount: correctCount ?? 0,
      incorrectCount: incorrectCount ?? 0,
      score: score ?? 0,
      percentage: percentage ?? 0.0,
      attemptNumber: attemptNumber,
      isPassed: isPassed ?? false,
      syncStatus: status,
    );
  }

  @override
  List<Object?> get props => [
    attemptId,
    studentId,
    quizId,
    courseId,
    attemptNumber,
    startedAt,
    deadline,
    answers,
    status,
    submittedAt,
    durationSecondsUsed,
    correctCount,
    incorrectCount,
    score,
    totalMarks,
    percentage,
    isPassed,
    lastSyncError,
    lastSyncAttempt,
    syncRetryCount,
  ];
}

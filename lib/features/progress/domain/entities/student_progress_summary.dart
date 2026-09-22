import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class ProgressWeighting extends Equatable {
  final double attendanceWeight; // e.g. 0.20
  final double quizWeight; // e.g. 0.35
  final double examWeight; // e.g. 0.45

  const ProgressWeighting({
    this.attendanceWeight = AppConstants.defaultAttendanceWeight,
    this.quizWeight = AppConstants.defaultQuizWeight,
    this.examWeight = AppConstants.defaultExamWeight,
  });

  @override
  List<Object?> get props => [attendanceWeight, quizWeight, examWeight];
}

class StudentProgressSummary extends Equatable {
  final String studentId;
  final String studentName;
  final String courseId;

  // Attendance metrics
  final int totalSessions;
  final int presentSessions;
  final int absentSessions;
  final int lateSessions;
  final double attendancePercentage;

  // Quizzes & Exams metrics
  final int completedQuizzesCount;
  final double quizAveragePercentage;
  final int completedExamsCount;
  final double examAveragePercentage;

  // Evaluations metrics
  final int totalBonusPoints;
  final int totalMinusPoints;
  final int netAdjustmentPoints;

  // Final Composite Score (Weighted Breakdown)
  final double finalCompositeScore; // 0 - 100
  final DateTime lastUpdated;

  const StudentProgressSummary({
    required this.studentId,
    required this.studentName,
    required this.courseId,
    this.totalSessions = 0,
    this.presentSessions = 0,
    this.absentSessions = 0,
    this.lateSessions = 0,
    this.attendancePercentage = 0.0,
    this.completedQuizzesCount = 0,
    this.quizAveragePercentage = 0.0,
    this.completedExamsCount = 0,
    this.examAveragePercentage = 0.0,
    this.totalBonusPoints = 0,
    this.totalMinusPoints = 0,
    this.netAdjustmentPoints = 0,
    this.finalCompositeScore = 0.0,
    required this.lastUpdated,
  });

  factory StudentProgressSummary.calculate({
    required String studentId,
    required String studentName,
    required String courseId,
    required int totalSessions,
    required int presentSessions,
    required int absentSessions,
    required int lateSessions,
    required int completedQuizzesCount,
    required double quizAveragePercentage,
    required int completedExamsCount,
    required double examAveragePercentage,
    required int totalBonusPoints,
    required int totalMinusPoints,
    ProgressWeighting weighting = const ProgressWeighting(),
  }) {
    final double attPct =
        totalSessions > 0
            ? ((presentSessions + (lateSessions * 0.5)) / totalSessions) * 100.0
            : 0.0;

    final int netAdj = totalBonusPoints - totalMinusPoints;

    // Redistribute the configured weights across categories with recorded work.
    // An unfinished category does not count as a zero grade.
    final activeWeight =
        (totalSessions > 0 ? weighting.attendanceWeight : 0.0) +
        (completedQuizzesCount > 0 ? weighting.quizWeight : 0.0) +
        (completedExamsCount > 0 ? weighting.examWeight : 0.0);
    final weightedScore =
        (totalSessions > 0 ? attPct * weighting.attendanceWeight : 0.0) +
        (completedQuizzesCount > 0
            ? quizAveragePercentage * weighting.quizWeight
            : 0.0) +
        (completedExamsCount > 0
            ? examAveragePercentage * weighting.examWeight
            : 0.0);
    final double totalScore =
        activeWeight > 0
            ? (weightedScore / activeWeight + netAdj).clamp(0.0, 100.0)
            : 0.0;

    return StudentProgressSummary(
      studentId: studentId,
      studentName: studentName,
      courseId: courseId,
      totalSessions: totalSessions,
      presentSessions: presentSessions,
      absentSessions: absentSessions,
      lateSessions: lateSessions,
      attendancePercentage: double.parse(attPct.toStringAsFixed(1)),
      completedQuizzesCount: completedQuizzesCount,
      quizAveragePercentage: double.parse(
        quizAveragePercentage.toStringAsFixed(1),
      ),
      completedExamsCount: completedExamsCount,
      examAveragePercentage: double.parse(
        examAveragePercentage.toStringAsFixed(1),
      ),
      totalBonusPoints: totalBonusPoints,
      totalMinusPoints: totalMinusPoints,
      netAdjustmentPoints: netAdj,
      finalCompositeScore: double.parse(totalScore.toStringAsFixed(1)),
      lastUpdated: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    courseId,
    totalSessions,
    presentSessions,
    absentSessions,
    lateSessions,
    attendancePercentage,
    completedQuizzesCount,
    quizAveragePercentage,
    completedExamsCount,
    examAveragePercentage,
    totalBonusPoints,
    totalMinusPoints,
    netAdjustmentPoints,
    finalCompositeScore,
    lastUpdated,
  ];
}

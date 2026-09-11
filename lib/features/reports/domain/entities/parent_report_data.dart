import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class ParentReportData extends Equatable {
  final String studentName;
  final StudentGrade? studentGrade;
  final String courseName;
  final String academicYear;
  final String reportingPeriod;
  final DateTime startDate;
  final DateTime endDate;

  // Attendance
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final double attendancePercentage;
  final List<Map<String, String>> sessionDetails; // date, status, note

  // Quizzes & Exams
  final List<Map<String, dynamic>>
  quizzes; // name, score, maxScore, percentage, date
  final List<Map<String, dynamic>>
  exams; // name, score, maxScore, percentage, date, duration
  final double quizAverage;
  final double examAverage;

  // Conduct / Bonus & Minus
  final List<Map<String, dynamic>> adjustments; // points, type, reason, date
  final int totalBonus;
  final int totalMinus;
  final int netAdjustments;

  // Teacher notes & Overall Evaluation
  final String? teacherNotes;
  final double overallEvaluation; // 0 - 100
  final String standingRemarks;

  const ParentReportData({
    required this.studentName,
    this.studentGrade,
    required this.courseName,
    required this.academicYear,
    required this.reportingPeriod,
    required this.startDate,
    required this.endDate,
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.attendancePercentage,
    this.sessionDetails = const [],
    this.quizzes = const [],
    this.exams = const [],
    required this.quizAverage,
    required this.examAverage,
    this.adjustments = const [],
    required this.totalBonus,
    required this.totalMinus,
    required this.netAdjustments,
    this.teacherNotes,
    required this.overallEvaluation,
    required this.standingRemarks,
  });

  @override
  List<Object?> get props => [
    studentName,
    studentGrade,
    courseName,
    academicYear,
    reportingPeriod,
    startDate,
    endDate,
    totalSessions,
    presentCount,
    absentCount,
    lateCount,
    attendancePercentage,
    sessionDetails,
    quizzes,
    exams,
    quizAverage,
    examAverage,
    adjustments,
    totalBonus,
    totalMinus,
    netAdjustments,
    teacherNotes,
    overallEvaluation,
    standingRemarks,
  ];
}

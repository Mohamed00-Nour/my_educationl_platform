import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/performance_rating.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../attendance/domain/repositories/attendance_repository.dart';
import '../../../evaluations/domain/repositories/evaluation_repository.dart';
import '../../../quizzes/domain/repositories/quiz_repository.dart';
import '../../domain/entities/student_progress_summary.dart';
import '../../domain/repositories/progress_repository.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  final AttendanceRepository _attendanceRepository;
  final QuizRepository _quizRepository;
  final EvaluationRepository _evaluationRepository;

  // In-memory summary cache with 5-minute TTL to minimize Firestore reads
  final Map<String, StudentProgressSummary> _cache = {};
  final Map<String, DateTime> _lastFetched = {};
  static const Duration _ttl = Duration(minutes: 5);

  ProgressRepositoryImpl({
    required AttendanceRepository attendanceRepository,
    required QuizRepository quizRepository,
    required EvaluationRepository evaluationRepository,
  }) : _attendanceRepository = attendanceRepository,
       _quizRepository = quizRepository,
       _evaluationRepository = evaluationRepository;

  @override
  Future<StudentProgressSummary> getStudentProgressSummary({
    required String studentId,
    required String studentName,
    required String courseId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        '${studentId}_${courseId}_${startDate?.millisecondsSinceEpoch}_${endDate?.millisecondsSinceEpoch}';

    if (!forceRefresh &&
        _cache.containsKey(cacheKey) &&
        _lastFetched.containsKey(cacheKey)) {
      if (DateTime.now().difference(_lastFetched[cacheKey]!) < _ttl) {
        return _cache[cacheKey]!;
      }
    }

    try {
      // 1. Fetch Attendance for this student
      var attendanceList = await _attendanceRepository
          .getAttendanceForStudent(studentId: studentId, courseId: courseId);

      if (startDate != null) {
        attendanceList = attendanceList.where((a) {
          final d = DateTime.tryParse(a.sessionDate) ?? a.timestamp;
          final isAfter = d.isAfter(startDate.subtract(const Duration(days: 1)));
          final isBefore =
              endDate == null || d.isBefore(endDate.add(const Duration(days: 1)));
          return isAfter && isBefore;
        }).toList();
      }

      int totalSessions = attendanceList.length;
      int present =
          attendanceList
              .where((a) => a.status == AttendanceStatus.present)
              .length;
      int absent =
          attendanceList
              .where((a) => a.status == AttendanceStatus.absent)
              .length;
      int lateCount =
          attendanceList.where((a) => a.status == AttendanceStatus.late).length;

      // 2. Fetch Exam & Quiz Attempts
      var attempts = await _quizRepository.getAttemptsForStudent(
        studentId,
        courseId: courseId,
      );

      if (startDate != null) {
        attempts = attempts.where((a) {
          final isAfter =
              a.submittedAt.isAfter(startDate.subtract(const Duration(days: 1)));
          final isBefore =
              endDate == null || a.submittedAt.isBefore(endDate.add(const Duration(days: 1)));
          return isAfter && isBefore;
        }).toList();
      }

      int quizCount = 0;
      double quizSum = 0.0;
      int examCount = 0;
      double examSum = 0.0;

      for (final a in attempts) {
        final normalizedPercentage = PerformanceRating.fromPercentage(
          a.percentage,
        ).percentage;
        if (a.durationSecondsUsed >= 1800) {
          examCount++;
          examSum += normalizedPercentage;
        } else {
          quizCount++;
          quizSum += normalizedPercentage;
        }
      }

      final double quizAvg = quizCount > 0 ? (quizSum / quizCount) : 0.0;
      final double examAvg = examCount > 0 ? (examSum / examCount) : 0.0;

      // 3. Fetch Evaluations (Bonus/Minus)
      var adjustments = await _evaluationRepository.getAdjustmentsForStudent(
        studentId: studentId,
        courseId: courseId,
      );

      if (startDate != null) {
        adjustments = adjustments.where((a) {
          final isAfter =
              a.date.isAfter(startDate.subtract(const Duration(days: 1)));
          final isBefore =
              endDate == null || a.date.isBefore(endDate.add(const Duration(days: 1)));
          return isAfter && isBefore;
        }).toList();
      }

      int bonus = 0;
      int minus = 0;
      for (final a in adjustments) {
        if (a.isBonus) {
          bonus += a.points.abs();
        } else {
          minus += a.points.abs();
        }
      }

      final summary = StudentProgressSummary.calculate(
        studentId: studentId,
        studentName: studentName,
        courseId: courseId,
        totalSessions: totalSessions,
        presentSessions: present,
        absentSessions: absent,
        lateSessions: lateCount,
        completedQuizzesCount: quizCount,
        quizAveragePercentage: quizAvg,
        completedExamsCount: examCount,
        examAveragePercentage: examAvg,
        totalBonusPoints: bonus,
        totalMinusPoints: minus,
      );

      _cache[cacheKey] = summary;
      _lastFetched[cacheKey] = DateTime.now();

      return summary;
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

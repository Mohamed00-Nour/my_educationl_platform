import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/progress/domain/entities/student_progress_summary.dart';

void main() {
  group('StudentProgressSummary Calculation Tests', () {
    test(
      'should calculate correct weighted composite score and attendance percentage',
      () {
        final summary = StudentProgressSummary.calculate(
          studentId: 'student_1',
          studentName: 'Samir Hassan',
          courseId: 'cs101_secondary',
          totalSessions: 10,
          presentSessions: 9,
          absentSessions: 1,
          lateSessions: 0,
          completedQuizzesCount: 4,
          quizAveragePercentage: 90.0,
          completedExamsCount: 1,
          examAveragePercentage: 80.0,
          totalBonusPoints: 5,
          totalMinusPoints: 2,
          weighting: const ProgressWeighting(
            attendanceWeight: 0.20, // 20%
            quizWeight: 0.35, // 35%
            examWeight: 0.45, // 45%
          ),
        );

        // Attendance % = 9 / 10 = 90.0%
        expect(summary.attendancePercentage, 90.0);

        // Base Score = (90 * 0.20) + (90 * 0.35) + (80 * 0.45) = 18 + 31.5 + 36 = 85.5
        // Net adjustments = +5 - 2 = +3
        // Total = 85.5 + 3 = 88.5%
        expect(summary.netAdjustmentPoints, 3);
        expect(summary.finalCompositeScore, 88.5);
      },
    );

    test('should clamp final score within 0 to 100 range', () {
      final summary = StudentProgressSummary.calculate(
        studentId: 'student_2',
        studentName: 'Top Performer',
        courseId: 'cs101_secondary',
        totalSessions: 10,
        presentSessions: 10,
        absentSessions: 0,
        lateSessions: 0,
        completedQuizzesCount: 5,
        quizAveragePercentage: 100.0,
        completedExamsCount: 2,
        examAveragePercentage: 100.0,
        totalBonusPoints: 20, // Huge bonus
        totalMinusPoints: 0,
      );

      expect(summary.finalCompositeScore, 100.0);
    });

    test('redistributes weights when no full exam has been completed', () {
      final summary = StudentProgressSummary.calculate(
        studentId: 'student_3',
        studentName: 'Learner',
        courseId: 'course_1',
        totalSessions: 2,
        presentSessions: 2,
        absentSessions: 0,
        lateSessions: 0,
        completedQuizzesCount: 4,
        quizAveragePercentage: 96.7,
        completedExamsCount: 0,
        examAveragePercentage: 0,
        totalBonusPoints: 0,
        totalMinusPoints: 0,
      );

      // (100 * 0.20 + 96.7 * 0.35) / (0.20 + 0.35) = 97.9.
      expect(summary.finalCompositeScore, 97.9);
    });

    test('a completed exam with zero marks still affects the score', () {
      final summary = StudentProgressSummary.calculate(
        studentId: 'student_4',
        studentName: 'Learner',
        courseId: 'course_1',
        totalSessions: 2,
        presentSessions: 2,
        absentSessions: 0,
        lateSessions: 0,
        completedQuizzesCount: 4,
        quizAveragePercentage: 96.7,
        completedExamsCount: 1,
        examAveragePercentage: 0,
        totalBonusPoints: 0,
        totalMinusPoints: 0,
      );

      expect(summary.finalCompositeScore, closeTo(53.8, 0.1));
    });

    test('shows no score before any graded activity', () {
      final summary = StudentProgressSummary.calculate(
        studentId: 'student_5',
        studentName: 'Learner',
        courseId: 'course_1',
        totalSessions: 0,
        presentSessions: 0,
        absentSessions: 0,
        lateSessions: 0,
        completedQuizzesCount: 0,
        quizAveragePercentage: 0,
        completedExamsCount: 0,
        examAveragePercentage: 0,
        totalBonusPoints: 5,
        totalMinusPoints: 0,
      );

      expect(summary.finalCompositeScore, 0);
    });
  });
}

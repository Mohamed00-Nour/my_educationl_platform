import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/constants/app_constants.dart';
import 'package:instructor/features/quizzes/domain/entities/quiz_entity.dart';
import 'package:instructor/features/reports/domain/entities/parent_report_data.dart';

void main() {
  group('ParentReportData & Custom Period Tests', () {
    test('constructs ParentReportData accurately with custom period dates', () {
      final start = DateTime(2026, 8, 15);
      final end = DateTime(2026, 9, 10);

      final report = ParentReportData(
        studentName: 'yousef khaled nour',
        studentGrade: StudentGrade.firstSecondary,
        courseName: 'البرمجة والذكاء الاصطناعي',
        academicYear: '2026-2027',
        reportingPeriod: 'مخصص (15/08/2026 إلى 10/09/2026)',
        startDate: start,
        endDate: end,
        totalSessions: 8,
        presentCount: 7,
        absentCount: 1,
        lateCount: 0,
        attendancePercentage: 87.5,
        quizzes: const [
          {
            'name': 'كويز الوحدة الأولى: الخوارزميات',
            'score': 10,
            'maxScore': 10,
            'percentage': 100.0,
            'date': '20/08/2026',
          }
        ],
        exams: const [
          {
            'name': 'امتحان الشهر الأول الشامل',
            'score': 28,
            'maxScore': 30,
            'percentage': 93.3,
            'date': '05/09/2026',
            'duration': '35 دقيقة',
          }
        ],
        quizAverage: 100.0,
        examAverage: 93.3,
        totalBonus: 4,
        totalMinus: 0,
        netAdjustments: 4,
        overallEvaluation: 95.0,
        standingRemarks: 'التقدير: ممتاز (A) • مستوى أكاديمي متميز وفائق',
      );

      expect(report.studentName, 'yousef khaled nour');
      expect(report.studentGrade, StudentGrade.firstSecondary);
      expect(report.quizzes.first['name'], 'كويز الوحدة الأولى: الخوارزميات');
      expect(report.exams.first['name'], 'امتحان الشهر الأول الشامل');
      expect(report.startDate, start);
      expect(report.endDate, end);
      expect(report.reportingPeriod, contains('مخصص'));
    });

    test('QuizEntity type mapping accurately distinguishes quiz vs fullExam', () {
      expect(QuizType.fromString('quiz'), QuizType.quiz);
      expect(QuizType.fromString('fullExam'), QuizType.fullExam);
      expect(QuizType.fromString('exam'), QuizType.fullExam);
      expect(QuizType.fromString(null), QuizType.quiz);
    });
  });
}

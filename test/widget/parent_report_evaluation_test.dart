import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/services/service_locator.dart';
import 'package:instructor/features/attendance/domain/entities/attendance_record.dart';
import 'package:instructor/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:instructor/features/evaluations/domain/repositories/evaluation_repository.dart';
import 'package:instructor/features/quizzes/domain/entities/exam_attempt_entity.dart';
import 'package:instructor/features/quizzes/domain/repositories/quiz_repository.dart';
import 'package:instructor/features/reports/presentation/screens/parent_report_screen.dart';
import 'package:mocktail/mocktail.dart';

class _AttendanceRepositoryMock extends Mock implements AttendanceRepository {}

class _QuizRepositoryMock extends Mock implements QuizRepository {}

class _EvaluationRepositoryMock extends Mock implements EvaluationRepository {}

void main() {
  testWidgets('parent report excludes unfinished exam weight', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final attendanceRepository = _AttendanceRepositoryMock();
    final quizRepository = _QuizRepositoryMock();
    final evaluationRepository = _EvaluationRepositoryMock();
    getIt.registerSingleton<AttendanceRepository>(attendanceRepository);
    getIt.registerSingleton<QuizRepository>(quizRepository);
    getIt.registerSingleton<EvaluationRepository>(evaluationRepository);
    addTearDown(() async {
      await getIt.unregister<EvaluationRepository>();
      await getIt.unregister<QuizRepository>();
      await getIt.unregister<AttendanceRepository>();
    });

    final now = DateTime.now();
    when(
      () => attendanceRepository.getAttendanceForStudent(
        studentId: 'student-1',
        courseId: 'course-1',
      ),
    ).thenAnswer(
      (_) async => List.generate(2, (index) {
        final date = now.subtract(Duration(days: index + 1));
        return AttendanceRecord(
          id: 'attendance-$index',
          courseId: 'course-1',
          sessionDate: date.toIso8601String().substring(0, 10),
          studentId: 'student-1',
          studentName: 'Student',
          status: AttendanceStatus.present,
          recordedBy: 'teacher-1',
          timestamp: date,
        );
      }),
    );
    when(
      () => quizRepository.getAttemptsForStudent(
        'student-1',
        courseId: 'course-1',
      ),
    ).thenAnswer(
      (_) async => List.generate(4, (index) {
        final date = now.subtract(Duration(days: index + 1));
        return ExamAttemptEntity(
          id: 'attempt-$index',
          studentId: 'student-1',
          examId: 'quiz-$index',
          courseId: 'course-1',
          startedAt: date.subtract(const Duration(minutes: 1)),
          submittedAt: date,
          durationSecondsUsed: 60,
          answers: const {},
          correctCount: 29,
          incorrectCount: 1,
          score: 29,
          percentage: 96.7,
          isPassed: true,
        );
      }),
    );
    when(
      () => quizRepository.getQuizzesForCourse('course-1'),
    ).thenAnswer((_) async => []);
    when(() => quizRepository.getQuizById(any())).thenAnswer((_) async => null);
    when(
      () => evaluationRepository.getAdjustmentsForStudent(
        studentId: 'student-1',
        courseId: 'course-1',
      ),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(
      const MaterialApp(
        home: ParentReportScreen(
          courseId: 'course-1',
          courseName: 'Course',
          studentId: 'student-1',
          studentName: 'Student',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('97.9% المجموع'), findsOneWidget);
  });
}

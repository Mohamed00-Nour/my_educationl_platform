import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:instructor/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:instructor/features/evaluations/domain/repositories/evaluation_repository.dart';
import 'package:instructor/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:instructor/features/quizzes/domain/entities/exam_attempt_entity.dart';
import 'package:instructor/features/quizzes/domain/entities/quiz_entity.dart';
import 'package:instructor/features/quizzes/domain/repositories/quiz_repository.dart';

class _AttendanceRepository extends Mock implements AttendanceRepository {}

class _EvaluationRepository extends Mock implements EvaluationRepository {}

class _QuizRepository extends Mock implements QuizRepository {}

void main() {
  test(
    'progress classifies attempts by quiz type rather than time spent',
    () async {
      final attendance = _AttendanceRepository();
      final evaluations = _EvaluationRepository();
      final quizzes = _QuizRepository();
      final now = DateTime.now();

      ExamAttemptEntity attempt(
        String examId,
        int seconds,
        double percentage,
      ) => ExamAttemptEntity(
        id: 'attempt-$examId',
        studentId: 'student',
        examId: examId,
        courseId: 'course',
        startedAt: now.subtract(Duration(seconds: seconds)),
        submittedAt: now,
        durationSecondsUsed: seconds,
        answers: const {},
        correctCount: 0,
        incorrectCount: 0,
        score: percentage.toInt(),
        percentage: percentage,
        isPassed: true,
      );

      when(
        () => attendance.getAttendanceForStudent(
          studentId: 'student',
          courseId: 'course',
        ),
      ).thenAnswer((_) async => []);
      when(
        () => evaluations.getAdjustmentsForStudent(
          studentId: 'student',
          courseId: 'course',
        ),
      ).thenAnswer((_) async => []);
      when(
        () => quizzes.getAttemptsForStudent('student', courseId: 'course'),
      ).thenAnswer(
        (_) async => [
          attempt('long-quiz', 1800, 90),
          attempt('short-exam', 120, 70),
        ],
      );
      when(() => quizzes.getQuizzesForCourse('course')).thenAnswer(
        (_) async => const [
          QuizEntity(
            id: 'long-quiz',
            title: 'Quiz',
            description: '',
            type: QuizType.quiz,
            courseId: 'course',
          ),
          QuizEntity(
            id: 'short-exam',
            title: 'Exam',
            description: '',
            type: QuizType.fullExam,
            courseId: 'course',
          ),
        ],
      );

      final summary = await ProgressRepositoryImpl(
        attendanceRepository: attendance,
        quizRepository: quizzes,
        evaluationRepository: evaluations,
      ).getStudentProgressSummary(
        studentId: 'student',
        studentName: 'Student',
        courseId: 'course',
      );

      expect(summary.completedQuizzesCount, 1);
      expect(summary.quizAveragePercentage, 90);
      expect(summary.completedExamsCount, 1);
      expect(summary.examAveragePercentage, 70);
    },
  );
}

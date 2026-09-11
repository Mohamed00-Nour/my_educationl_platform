import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/quizzes/data/models/local_attempt_model.dart';
import 'package:instructor/features/quizzes/domain/entities/local_attempt_entity.dart';

void main() {
  group('LocalAttemptModel & Timer Tests', () {
    test(
      'LocalAttemptModel serialization and deserialization should preserve all fields',
      () {
        final started = DateTime.now().subtract(const Duration(minutes: 5));
        final deadline = started.add(const Duration(minutes: 30));
        final submitted = DateTime.now();

        final model = LocalAttemptModel(
          attemptId: 'att-uuid-1234',
          studentId: 'student-99',
          quizId: 'quiz-01',
          courseId: 'course-alpha',
          attemptNumber: 2,
          startedAt: started,
          deadline: deadline,
          answers: const {'q1': 0, 'q2': 2, 'q3': 1},
          status: AttemptSyncStatus.completedPendingSync,
          submittedAt: submitted,
          durationSecondsUsed: 300,
          correctCount: 2,
          incorrectCount: 1,
          score: 20,
          totalMarks: 30,
          percentage: 66.7,
          isPassed: true,
          lastSyncError: 'Network unreachable',
          syncRetryCount: 1,
        );

        final json = model.toJson();
        final restored = LocalAttemptModel.fromJson(json);

        expect(restored.attemptId, equals('att-uuid-1234'));
        expect(restored.studentId, equals('student-99'));
        expect(restored.quizId, equals('quiz-01'));
        expect(restored.courseId, equals('course-alpha'));
        expect(restored.attemptNumber, equals(2));
        expect(restored.answers, equals({'q1': 0, 'q2': 2, 'q3': 1}));
        expect(restored.status, equals(AttemptSyncStatus.completedPendingSync));
        expect(restored.durationSecondsUsed, equals(300));
        expect(restored.correctCount, equals(2));
        expect(restored.incorrectCount, equals(1));
        expect(restored.score, equals(20));
        expect(restored.totalMarks, equals(30));
        expect(restored.percentage, equals(66.7));
        expect(restored.isPassed, isTrue);
        expect(restored.lastSyncError, equals('Network unreachable'));
        expect(restored.syncRetryCount, equals(1));
      },
    );

    test(
      'remainingSeconds is correctly calculated from timestamps and survives in-memory reset',
      () {
        final now = DateTime.now();
        // Started 10 minutes ago, total duration 25 minutes => 15 minutes left
        final startedAt = now.subtract(const Duration(minutes: 10));
        final deadline = startedAt.add(const Duration(minutes: 25));

        final attempt = LocalAttemptEntity(
          attemptId: 'test-timer-1',
          studentId: 'std-1',
          quizId: 'q-1',
          courseId: 'c-1',
          startedAt: startedAt,
          deadline: deadline,
        );

        final remaining = attempt.remainingSeconds;
        // Expect approximately 15 minutes = 900 seconds (allowing +/- 5 seconds for execution latency)
        expect(remaining >= 890 && remaining <= 905, isTrue);
        expect(attempt.isExpired, isFalse);
      },
    );

    test(
      'expired deadline correctly identifies attempt as expired and clamps remaining to 0',
      () {
        final now = DateTime.now();
        // Started 60 minutes ago, duration 30 minutes => expired 30 minutes ago
        final startedAt = now.subtract(const Duration(minutes: 60));
        final deadline = startedAt.add(const Duration(minutes: 30));

        final attempt = LocalAttemptEntity(
          attemptId: 'test-timer-expired',
          studentId: 'std-1',
          quizId: 'q-1',
          courseId: 'c-1',
          startedAt: startedAt,
          deadline: deadline,
        );

        expect(attempt.remainingSeconds, equals(0));
        expect(attempt.isExpired, isTrue);
      },
    );

    test(
      'toExamAttemptEntity converts accurately for downstream consumers',
      () {
        final started = DateTime.now().subtract(const Duration(minutes: 15));
        final deadline = started.add(const Duration(minutes: 30));
        final submitted = DateTime.now();

        final localAttempt = LocalAttemptEntity(
          attemptId: 'unified-attempt-id',
          studentId: 'student-42',
          quizId: 'exam-101',
          courseId: 'math-101',
          attemptNumber: 1,
          startedAt: started,
          deadline: deadline,
          submittedAt: submitted,
          answers: const {'q1': 1, 'q2': 3},
          correctCount: 2,
          incorrectCount: 0,
          score: 10,
          totalMarks: 10,
          percentage: 100.0,
          isPassed: true,
          durationSecondsUsed: 900,
          status: AttemptSyncStatus.synced,
        );

        final examAttempt = localAttempt.toExamAttemptEntity();

        expect(examAttempt.id, equals('unified-attempt-id'));
        expect(examAttempt.studentId, equals('student-42'));
        expect(examAttempt.examId, equals('exam-101'));
        expect(examAttempt.courseId, equals('math-101'));
        expect(examAttempt.score, equals(10));
        expect(examAttempt.percentage, equals(100.0));
        expect(examAttempt.isPassed, isTrue);
        expect(examAttempt.syncStatus, equals(AttemptSyncStatus.synced));
      },
    );
  });
}

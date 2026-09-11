import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:instructor/core/errors/exceptions.dart';
import 'package:instructor/features/quizzes/data/datasources/exam_local_data_source.dart';
import 'package:instructor/features/quizzes/data/datasources/quiz_remote_data_source.dart';
import 'package:instructor/features/quizzes/data/models/exam_attempt_model.dart';
import 'package:instructor/features/quizzes/data/models/local_attempt_model.dart';
import 'package:instructor/features/quizzes/data/models/quiz_model.dart';
import 'package:instructor/features/quizzes/data/repositories/quiz_repository_impl.dart';
import 'package:instructor/features/quizzes/domain/entities/local_attempt_entity.dart';
import 'package:instructor/features/quizzes/domain/entities/quiz_entity.dart';

class MockQuizRemoteDataSource extends Mock implements QuizRemoteDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      ExamAttemptModel(
        id: 'fallback',
        studentId: 'fallback',
        examId: 'fallback',
        courseId: 'fallback',
        startedAt: DateTime.now(),
        submittedAt: DateTime.now(),
        durationSecondsUsed: 0,
        answers: const {},
        correctCount: 0,
        incorrectCount: 0,
        score: 0,
        percentage: 0,
        isPassed: false,
      ),
    );
  });

  group('Offline Caching & Local Persistence (ExamLocalDataSource)', () {
    late SharedPreferences prefs;
    late ExamLocalDataSource localDataSource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      localDataSource = ExamLocalDataSourceImpl(prefs);
    });

    test(
      'cacheQuiz and getCachedQuiz should store and retrieve full quiz data offline',
      () async {
        const quiz = QuizModel(
          id: 'quiz_offline_1',
          title: 'Offline Math Quiz',
          description: 'Testing offline caching',
          type: QuizType.quiz,
          courseId: 'course_101',
          durationMinutes: 20,
          totalMarks: 50,
          passingScore: 25,
          requireStartCode: true,
          startCode: '123456',
          startCodeHash: 'dummyhash',
          startCodeSalt: 'dummysalt',
        );

        // Cache it
        await localDataSource.cacheQuiz(quiz);

        // Check availability
        final isAvailable = await localDataSource.isQuizAvailableOffline(
          'quiz_offline_1',
        );
        expect(isAvailable, isTrue);

        // Retrieve
        final cached = await localDataSource.getCachedQuiz('quiz_offline_1');
        expect(cached, isNotNull);
        expect(cached!.id, equals('quiz_offline_1'));
        expect(cached.title, equals('Offline Math Quiz'));
        expect(cached.requireStartCode, isTrue);
        expect(cached.startCodeHash, equals('dummyhash'));
        expect(cached.startCodeSalt, equals('dummysalt'));

        // Retrieve all
        final all = await localDataSource.getAllCachedQuizzes();
        expect(all.length, equals(1));
        expect(all.first.id, equals('quiz_offline_1'));

        // Remove from cache
        await localDataSource.removeCachedQuiz('quiz_offline_1');
        final afterRemove = await localDataSource.getCachedQuiz('quiz_offline_1');
        expect(afterRemove, isNull);
      },
    );

    test(
      'saveActiveAttempt and loadActiveAttempt survives app crash / restart simulation',
      () async {
        final started = DateTime.now();
        final deadline = started.add(const Duration(minutes: 15));

        final attempt = LocalAttemptModel(
          attemptId: 'crash-resilient-id',
          studentId: 'std_42',
          quizId: 'quiz_crash_test',
          courseId: 'course_1',
          startedAt: started,
          deadline: deadline,
          answers: const {'q1': 2},
          status: AttemptSyncStatus.inProgress,
        );

        await localDataSource.saveActiveAttempt(attempt);

        // Load it back (simulating app relaunch)
        final restored = await localDataSource.loadActiveAttempt(
          'quiz_crash_test',
          'std_42',
        );
        expect(restored, isNotNull);
        expect(restored!.attemptId, equals('crash-resilient-id'));
        expect(restored.answers, equals({'q1': 2}));
        expect(restored.status, equals(AttemptSyncStatus.inProgress));

        // Clearing active attempt removes it
        await localDataSource.clearActiveAttempt('quiz_crash_test', 'std_42');
        final afterClear = await localDataSource.loadActiveAttempt(
          'quiz_crash_test',
          'std_42',
        );
        expect(afterClear, isNull);
      },
    );

    test(
      'pending attempts tracking works accurately across sync status changes',
      () async {
        final started = DateTime.now();
        final deadline = started.add(const Duration(minutes: 15));

        final completedPending = LocalAttemptModel(
          attemptId: 'attempt-pending-1',
          studentId: 'student-A',
          quizId: 'quiz-A',
          courseId: 'course-A',
          startedAt: started,
          deadline: deadline,
          submittedAt: DateTime.now(),
          score: 10,
          status: AttemptSyncStatus.completedPendingSync,
        );

        // Save as pending sync
        await localDataSource.saveCompletedAttempt(completedPending);

        final pendingList = await localDataSource.getPendingAttempts();
        expect(pendingList.length, equals(1));
        expect(pendingList.first.attemptId, equals('attempt-pending-1'));

        // Update status to synced
        await localDataSource.updateAttemptStatus(
          'attempt-pending-1',
          AttemptSyncStatus.synced,
        );

        final pendingAfterSync = await localDataSource.getPendingAttempts();
        expect(pendingAfterSync.isEmpty, isTrue);

        // But still available in student history locally
        final studentHistory = await localDataSource.getCompletedAttempts(
          'student-A',
        );
        expect(studentHistory.length, equals(1));
        expect(studentHistory.first.status, equals(AttemptSyncStatus.synced));
      },
    );
  });

  group('Idempotent Synchronization Tests (QuizRepositoryImpl)', () {
    late MockQuizRemoteDataSource mockRemoteDataSource;
    late ExamLocalDataSource localDataSource;
    late QuizRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      localDataSource = ExamLocalDataSourceImpl(prefs);
      mockRemoteDataSource = MockQuizRemoteDataSource();
      repository = QuizRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: localDataSource,
      );
    });

    test(
      'syncAttempt succeeds and sets status to synced on successful remote write',
      () async {
        const stableAttemptId = 'idempotent-uuid-999';
        final now = DateTime.now();

        final attempt = LocalAttemptEntity(
          attemptId: stableAttemptId,
          studentId: 'student_1',
          quizId: 'exam_1',
          courseId: 'course_1',
          startedAt: now.subtract(const Duration(minutes: 10)),
          deadline: now.add(const Duration(minutes: 10)),
          submittedAt: now,
          score: 18,
          totalMarks: 20,
          status: AttemptSyncStatus.completedPendingSync,
        );

        // Save completed attempt locally first
        await localDataSource.saveCompletedAttempt(
          LocalAttemptModel.fromEntity(attempt),
        );

        // Mock remote data source successful save
        when(() => mockRemoteDataSource.submitExamAttempt(any())).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments[0] as ExamAttemptModel,
        );

        // Execute sync
        final result = await repository.syncAttempt(attempt);

        expect(result.status, equals(AttemptSyncStatus.synced));
        expect(result.attemptId, equals(stableAttemptId));
        verify(() => mockRemoteDataSource.submitExamAttempt(any())).called(1);

        // Check that pending queue is now empty
        final pending = await repository.getPendingAttempts();
        expect(pending.isEmpty, isTrue);
      },
    );

    test(
      'syncAttempt preserves attempt locally with syncFailed when network throws error',
      () async {
        const stableAttemptId = 'offline-uuid-888';
        final now = DateTime.now();

        final attempt = LocalAttemptEntity(
          attemptId: stableAttemptId,
          studentId: 'student_1',
          quizId: 'exam_1',
          courseId: 'course_1',
          startedAt: now.subtract(const Duration(minutes: 10)),
          deadline: now.add(const Duration(minutes: 10)),
          submittedAt: now,
          score: 15,
          totalMarks: 20,
          status: AttemptSyncStatus.completedPendingSync,
        );

        await localDataSource.saveCompletedAttempt(
          LocalAttemptModel.fromEntity(attempt),
        );

        // Remote throws ServerException (network offline)
        when(
          () => mockRemoteDataSource.submitExamAttempt(any()),
        ).thenThrow(ServerException('Network connection failed'));

        // Attempt sync
        final result = await repository.syncAttempt(attempt);

        // Status becomes syncFailed
        expect(result.status, equals(AttemptSyncStatus.syncFailed));
        expect(result.syncRetryCount, equals(1));
        expect(result.lastSyncError, contains('Network connection failed'));

        // CRITICAL REQUIREMENT: Local attempt is NOT DELETED or lost
        final pending = await repository.getPendingAttempts();
        expect(pending.length, equals(1));
        expect(pending.first.attemptId, equals(stableAttemptId));
        expect(pending.first.score, equals(15));
      },
    );

    test(
      'calling syncAttempt multiple times with same attemptId is idempotent',
      () async {
        const stableAttemptId = 'repeat-sync-uuid-777';
        final now = DateTime.now();

        final attempt = LocalAttemptEntity(
          attemptId: stableAttemptId,
          studentId: 'student_1',
          quizId: 'exam_1',
          courseId: 'course_1',
          startedAt: now.subtract(const Duration(minutes: 10)),
          deadline: now.add(const Duration(minutes: 10)),
          submittedAt: now,
          score: 20,
          totalMarks: 20,
          status: AttemptSyncStatus.completedPendingSync,
        );

        await localDataSource.saveCompletedAttempt(
          LocalAttemptModel.fromEntity(attempt),
        );

        when(() => mockRemoteDataSource.submitExamAttempt(any())).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments[0] as ExamAttemptModel,
        );

        // First sync
        final res1 = await repository.syncAttempt(attempt);
        expect(res1.status, equals(AttemptSyncStatus.synced));

        // Second sync (already marked synced)
        final res2 = await repository.syncAttempt(res1);
        expect(res2.status, equals(AttemptSyncStatus.synced));

        // Should not call remote source again because it is already synced
        verify(() => mockRemoteDataSource.submitExamAttempt(any())).called(1);
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/quizzes/data/datasources/exam_local_data_source.dart';
import 'package:instructor/features/quizzes/data/datasources/quiz_remote_data_source.dart';
import 'package:instructor/features/quizzes/data/models/exam_attempt_model.dart';
import 'package:instructor/features/quizzes/data/models/local_attempt_model.dart';
import 'package:instructor/features/quizzes/data/repositories/quiz_repository_impl.dart';
import 'package:instructor/features/quizzes/domain/entities/local_attempt_entity.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RemoteQuizzes extends Mock implements QuizRemoteDataSource {}

void main() {
  test('student sees a submitted attempt while it is still syncing', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final local = ExamLocalDataSourceImpl(prefs);
    final remote = _RemoteQuizzes();
    final now = DateTime.now();
    final pending = LocalAttemptModel(
      attemptId: 'pending-attempt',
      studentId: 'student',
      quizId: 'quiz',
      courseId: 'course',
      startedAt: now.subtract(const Duration(minutes: 2)),
      deadline: now.add(const Duration(minutes: 13)),
      submittedAt: now,
      durationSecondsUsed: 120,
      score: 5,
      totalMarks: 10,
      percentage: 50,
      status: AttemptSyncStatus.completedPendingSync,
    );
    await local.saveCompletedAttempt(pending);
    when(
      () => remote.getAttemptsForStudent('student', courseId: 'course'),
    ).thenAnswer((_) async => <ExamAttemptModel>[]);

    final repository = QuizRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
    );
    final attempts = await repository.getAttemptsForStudent(
      'student',
      courseId: 'course',
    );

    expect(attempts, hasLength(1));
    expect(attempts.single.id, 'pending-attempt');
    expect(attempts.single.examId, 'quiz');

    await local.updateAttemptStatus(
      'pending-attempt',
      AttemptSyncStatus.synced,
    );
    final serverOnly = await repository.getAttemptsForStudent(
      'student',
      courseId: 'course',
    );
    expect(serverOnly, isEmpty);
  });
}

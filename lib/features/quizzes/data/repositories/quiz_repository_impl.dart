import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/exam_attempt_entity.dart';
import '../../domain/entities/local_attempt_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/quiz_entity.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../datasources/exam_local_data_source.dart';
import '../datasources/quiz_remote_data_source.dart';
import '../models/exam_attempt_model.dart';
import '../models/local_attempt_model.dart';
import '../models/question_model.dart';
import '../models/quiz_model.dart';

class QuizRepositoryImpl implements QuizRepository {
  final QuizRemoteDataSource _remoteDataSource;
  final ExamLocalDataSource _localDataSource;

  QuizRepositoryImpl({
    required QuizRemoteDataSource remoteDataSource,
    required ExamLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  @override
  Future<QuizEntity?> getQuizById(String quizId) async {
    try {
      final remoteQuiz = await _remoteDataSource
          .getQuizById(quizId)
          .timeout(const Duration(seconds: 4));
      if (remoteQuiz != null) {
        // Automatically update local cache for offline resilience
        await _localDataSource.cacheQuiz(remoteQuiz);
        return remoteQuiz;
      }
    } catch (_) {
      // Fallback to local offline cache if remote is unreachable or timed out
      final cachedQuiz = await _localDataSource.getCachedQuiz(quizId);
      if (cachedQuiz != null) {
        return cachedQuiz;
      }
    }

    // Secondary fallback to local cache
    return await _localDataSource.getCachedQuiz(quizId);
  }

  @override
  Future<List<QuizEntity>> getQuizzesForCourse(String courseId) async {
    try {
      final quizzes = await _remoteDataSource
          .getQuizzesForCourse(courseId)
          .timeout(const Duration(seconds: 4));
      // Cache fetched quizzes locally
      for (final q in quizzes) {
        await _localDataSource.cacheQuiz(q);
      }
      return quizzes;
    } catch (_) {
      // If offline, retrieve all cached quizzes that match courseId
      final cached = await _localDataSource.getAllCachedQuizzes();
      if (courseId.isNotEmpty) {
        final filtered = cached.where((q) => q.courseId == courseId).toList();
        if (filtered.isNotEmpty) return filtered;
      }
      return cached;
    }
  }

  @override
  Future<QuizEntity> createQuiz(QuizEntity quiz) async {
    try {
      final created = await _remoteDataSource.createQuiz(
        QuizModel.fromEntity(quiz),
      );
      await _localDataSource.cacheQuiz(created);
      return created;
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateQuiz(QuizEntity quiz) async {
    try {
      final model = QuizModel.fromEntity(quiz);
      await _remoteDataSource.updateQuiz(model);
      await _localDataSource.cacheQuiz(model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteQuiz(String quizId) async {
    try {
      await _remoteDataSource.deleteQuiz(quizId);
      await _localDataSource.removeCachedQuiz(quizId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<ExamAttemptEntity> submitExamAttempt(ExamAttemptEntity attempt) async {
    try {
      // Clear local in-progress draft/attempt upon submission
      await _localDataSource.clearActiveAttempt(
        attempt.examId,
        attempt.studentId,
      );
      final model = ExamAttemptModel.fromEntity(attempt);
      return await _remoteDataSource.submitExamAttempt(model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<ExamAttemptEntity>> getAttemptsForStudent(
    String studentId, {
    String? courseId,
  }) async {
    try {
      return await _remoteDataSource.getAttemptsForStudent(
        studentId,
        courseId: courseId,
      );
    } catch (_) {
      // Fallback to locally stored completed attempts when offline
      final localAttempts = await _localDataSource.getCompletedAttempts(
        studentId,
      );
      var entities = localAttempts.map((a) => a.toExamAttemptEntity()).toList();
      if (courseId != null && courseId.isNotEmpty) {
        entities = entities.where((a) => a.courseId == courseId).toList();
      }
      return entities;
    }
  }

  @override
  Future<List<ExamAttemptEntity>> getAttemptsForExam(String examId) async {
    try {
      return await _remoteDataSource.getAttemptsForExam(examId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<QuestionEntity>> getQuestionBank({
    String? courseId,
    String? topic,
    String? difficulty,
  }) async {
    try {
      return await _remoteDataSource.getQuestionBank(
        courseId: courseId,
        topic: topic,
        difficulty: difficulty,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> saveQuestionsToBank(List<QuestionEntity> questions) async {
    try {
      final models = questions.map((q) => QuestionModel.fromEntity(q)).toList();
      await _remoteDataSource.saveQuestionsToBank(models);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  // ==========================================
  // LEGACY AUTOSAVE METHODS
  // ==========================================

  @override
  Future<void> saveActiveExamDraftLocally({
    required String quizId,
    required String studentId,
    required Map<String, int> answers,
    required int remainingSeconds,
  }) async {
    await _localDataSource.saveActiveExamDraft(
      quizId: quizId,
      studentId: studentId,
      answers: answers,
      remainingSeconds: remainingSeconds,
    );
  }

  @override
  Future<LocalExamDraft?> loadActiveExamDraftLocally({
    required String quizId,
    required String studentId,
  }) async {
    return await _localDataSource.loadActiveExamDraft(
      quizId: quizId,
      studentId: studentId,
    );
  }

  @override
  Future<void> clearActiveExamDraftLocally({
    required String quizId,
    required String studentId,
  }) async {
    await _localDataSource.clearActiveExamDraft(
      quizId: quizId,
      studentId: studentId,
    );
  }

  // ==========================================
  // OFFLINE-FIRST QUIZ CACHING
  // ==========================================

  @override
  Future<void> cacheQuizForOffline(QuizEntity quiz) async {
    await _localDataSource.cacheQuiz(QuizModel.fromEntity(quiz));
  }

  @override
  Future<QuizEntity?> getCachedQuiz(String quizId) async {
    return await _localDataSource.getCachedQuiz(quizId);
  }

  @override
  Future<List<QuizEntity>> getAllCachedQuizzes() async {
    return await _localDataSource.getAllCachedQuizzes();
  }

  @override
  Future<bool> isQuizAvailableOffline(String quizId) async {
    return await _localDataSource.isQuizAvailableOffline(quizId);
  }

  @override
  Future<void> removeCachedQuiz(String quizId) async {
    await _localDataSource.removeCachedQuiz(quizId);
  }

  // ==========================================
  // RELIABLE ATTEMPT ENGINE & PERSISTENCE
  // ==========================================

  @override
  Future<void> saveActiveAttemptLocally(LocalAttemptEntity attempt) async {
    await _localDataSource.saveActiveAttempt(
      LocalAttemptModel.fromEntity(attempt),
    );
  }

  @override
  Future<LocalAttemptEntity?> loadActiveAttemptLocally(
    String quizId,
    String studentId,
  ) async {
    return await _localDataSource.loadActiveAttempt(quizId, studentId);
  }

  @override
  Future<void> clearActiveAttemptLocally(
    String quizId,
    String studentId,
  ) async {
    await _localDataSource.clearActiveAttempt(quizId, studentId);
  }

  @override
  Future<void> saveCompletedAttemptLocally(LocalAttemptEntity attempt) async {
    await _localDataSource.saveCompletedAttempt(
      LocalAttemptModel.fromEntity(attempt),
    );
  }

  @override
  Future<List<LocalAttemptEntity>> getPendingAttempts() async {
    return await _localDataSource.getPendingAttempts();
  }

  @override
  Future<List<LocalAttemptEntity>> getCompletedAttemptsLocally(
    String studentId,
  ) async {
    return await _localDataSource.getCompletedAttempts(studentId);
  }

  @override
  Future<LocalAttemptEntity> syncAttempt(LocalAttemptEntity attempt) async {
    if (attempt.status == AttemptSyncStatus.synced) {
      return attempt;
    }

    // Mark syncing in local storage
    await _localDataSource.updateAttemptStatus(
      attempt.attemptId,
      AttemptSyncStatus.syncing,
    );

    try {
      final examAttempt = attempt.toExamAttemptEntity();
      final model = ExamAttemptModel.fromEntity(examAttempt);

      // Submit via idempotent remote call
      final savedModel = await _remoteDataSource.submitExamAttempt(model);

      // Confirm success in local storage
      await _localDataSource.updateAttemptStatus(
        attempt.attemptId,
        AttemptSyncStatus.synced,
      );

      return attempt.copyWith(
        status: AttemptSyncStatus.synced,
        attemptId: savedModel.id,
        lastSyncAttempt: DateTime.now(),
        lastSyncError: null,
      );
    } catch (e) {
      // NEVER DELETE OR CLEAR LOCAL ATTEMPT ON FAILURE
      final errorMessage = e.toString();
      await _localDataSource.updateAttemptStatus(
        attempt.attemptId,
        AttemptSyncStatus.syncFailed,
        error: errorMessage,
      );

      return attempt.copyWith(
        status: AttemptSyncStatus.syncFailed,
        lastSyncError: errorMessage,
        lastSyncAttempt: DateTime.now(),
        syncRetryCount: attempt.syncRetryCount + 1,
      );
    }
  }

  @override
  Future<List<LocalAttemptEntity>> syncAllPendingAttempts() async {
    final pending = await _localDataSource.getPendingAttempts();
    final List<LocalAttemptEntity> syncedResults = [];

    for (final attempt in pending) {
      final result = await syncAttempt(attempt);
      syncedResults.add(result);
    }

    return syncedResults;
  }
}

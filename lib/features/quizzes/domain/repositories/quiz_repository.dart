import '../entities/exam_attempt_entity.dart';
import '../entities/local_attempt_entity.dart';
import '../entities/question_entity.dart';
import '../entities/quiz_entity.dart';

class LocalExamDraft {
  final Map<String, int> answers;
  final int remainingSeconds;
  final DateTime savedAt;

  const LocalExamDraft({
    required this.answers,
    required this.remainingSeconds,
    required this.savedAt,
  });
}

abstract class QuizRepository {
  Future<QuizEntity?> getQuizById(String quizId);
  Future<List<QuizEntity>> getQuizzesForCourse(String courseId);
  Future<QuizEntity> createQuiz(QuizEntity quiz);
  Future<void> updateQuiz(QuizEntity quiz);
  Future<void> deleteQuiz(String quizId);

  // Exam Attempt Recording
  Future<ExamAttemptEntity> submitExamAttempt(ExamAttemptEntity attempt);
  Future<List<ExamAttemptEntity>> getAttemptsForStudent(
    String studentId, {
    String? courseId,
  });
  Future<List<ExamAttemptEntity>> getAttemptsForExam(String examId);

  // Question Bank
  Future<List<QuestionEntity>> getQuestionBank({
    String? courseId,
    String? topic,
    String? difficulty,
  });
  Future<void> saveQuestionsToBank(List<QuestionEntity> questions);

  // Zero-cost Local Autosave & Crash Resilience (Legacy support)
  Future<void> saveActiveExamDraftLocally({
    required String quizId,
    required String studentId,
    required Map<String, int> answers,
    required int remainingSeconds,
  });
  Future<LocalExamDraft?> loadActiveExamDraftLocally({
    required String quizId,
    required String studentId,
  });
  Future<void> clearActiveExamDraftLocally({
    required String quizId,
    required String studentId,
  });

  // Offline-First Quiz & Exam Caching
  Future<void> cacheQuizForOffline(QuizEntity quiz);
  Future<QuizEntity?> getCachedQuiz(String quizId);
  Future<List<QuizEntity>> getAllCachedQuizzes();
  Future<bool> isQuizAvailableOffline(String quizId);
  Future<void> removeCachedQuiz(String quizId);

  // Reliable Offline-First Attempt Engine
  Future<void> saveActiveAttemptLocally(LocalAttemptEntity attempt);
  Future<LocalAttemptEntity?> loadActiveAttemptLocally(
    String quizId,
    String studentId,
  );
  Future<void> clearActiveAttemptLocally(String quizId, String studentId);
  Future<void> saveCompletedAttemptLocally(LocalAttemptEntity attempt);
  Future<List<LocalAttemptEntity>> getPendingAttempts();
  Future<List<LocalAttemptEntity>> getCompletedAttemptsLocally(
    String studentId,
  );
  Future<LocalAttemptEntity> syncAttempt(LocalAttemptEntity attempt);
  Future<List<LocalAttemptEntity>> syncAllPendingAttempts();
}

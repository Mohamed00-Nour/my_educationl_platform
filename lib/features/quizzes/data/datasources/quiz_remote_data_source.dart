import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/exam_attempt_model.dart';
import '../models/question_model.dart';
import '../models/quiz_model.dart';

abstract class QuizRemoteDataSource {
  Future<QuizModel?> getQuizById(String quizId);
  Future<List<QuizModel>> getQuizzesForCourse(String courseId);
  Future<QuizModel> createQuiz(QuizModel quiz);
  Future<void> updateQuiz(QuizModel quiz);
  Future<void> deleteQuiz(String quizId);

  Future<ExamAttemptModel> submitExamAttempt(ExamAttemptModel attempt);
  Future<List<ExamAttemptModel>> getAttemptsForStudent(
    String studentId, {
    String? courseId,
  });
  Future<List<ExamAttemptModel>> getAttemptsForExam(String examId);

  Future<List<QuestionModel>> getQuestionBank({
    String? courseId,
    String? topic,
    String? difficulty,
  });
  Future<void> saveQuestionsToBank(List<QuestionModel> questions);
}

class QuizRemoteDataSourceImpl implements QuizRemoteDataSource {
  final FirebaseFirestore _firestore;

  QuizRemoteDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<QuizModel?> getQuizById(String quizId) async {
    try {
      final doc =
          await _firestore
              .collection(FirestoreCollections.quizzes)
              .doc(quizId)
              .get();
      if (!doc.exists) return null;
      return QuizModel.fromFirestore(doc);
    } catch (e) {
      throw ServerException('Failed to load quiz: $e');
    }
  }

  @override
  Future<List<QuizModel>> getQuizzesForCourse(String courseId) async {
    try {
      Query collectionRef = _firestore.collection(FirestoreCollections.quizzes);
      if (courseId.isNotEmpty) {
        collectionRef = collectionRef.where('courseId', isEqualTo: courseId);
      }
      final snapshot = await collectionRef.get();

      return snapshot.docs.map((d) => QuizModel.fromFirestore(d)).toList();
    } catch (e) {
      throw ServerException('Failed to load course quizzes: $e');
    }
  }

  @override
  Future<QuizModel> createQuiz(QuizModel quiz) async {
    try {
      final docRef = _firestore.collection(FirestoreCollections.quizzes).doc();
      final modelToSave = QuizModel(
        id: docRef.id,
        title: quiz.title,
        description: quiz.description,
        type: quiz.type,
        courseId: quiz.courseId,
        unitId: quiz.unitId,
        lessonId: quiz.lessonId,
        durationMinutes: quiz.durationMinutes,
        totalMarks: quiz.totalMarks,
        passingScore: quiz.passingScore,
        maxAttempts: quiz.maxAttempts,
        availableFrom: quiz.availableFrom,
        availableUntil: quiz.availableUntil,
        shuffleQuestions: quiz.shuffleQuestions,
        shuffleOptions: quiz.shuffleOptions,
        showResultImmediately: quiz.showResultImmediately,
        showCorrectAnswers: quiz.showCorrectAnswers,
        showExplanations: quiz.showExplanations,
        isPublished: quiz.isPublished,
        questions: quiz.questions,
        createdAt: quiz.createdAt ?? DateTime.now(),
        requireStartCode: quiz.requireStartCode,
        startCode: quiz.startCode,
        startCodeHash: quiz.startCodeHash,
        startCodeSalt: quiz.startCodeSalt,
      );

      await docRef.set(modelToSave.toMap());
      return modelToSave;
    } catch (e) {
      throw ServerException('Failed to save quiz: $e');
    }
  }

  @override
  Future<void> updateQuiz(QuizModel quiz) async {
    try {
      await _firestore
          .collection(FirestoreCollections.quizzes)
          .doc(quiz.id)
          .update(quiz.toMap());
    } catch (e) {
      throw ServerException('Failed to update quiz: $e');
    }
  }

  @override
  Future<void> deleteQuiz(String quizId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.quizzes)
          .doc(quizId)
          .delete();
    } catch (e) {
      throw ServerException('Failed to delete quiz: $e');
    }
  }

  @override
  Future<ExamAttemptModel> submitExamAttempt(ExamAttemptModel attempt) async {
    try {
      final attemptDocId =
          attempt.id.isNotEmpty
              ? attempt.id
              : _firestore
                  .collection(FirestoreCollections.examAttempts)
                  .doc()
                  .id;
      final docRef = _firestore
          .collection(FirestoreCollections.examAttempts)
          .doc(attemptDocId);

      // Check if this exact attempt was already successfully persisted (Idempotency)
      final existingDoc = await docRef.get();
      if (existingDoc.exists) {
        return ExamAttemptModel.fromFirestore(existingDoc);
      }

      final modelToSave = ExamAttemptModel(
        id: attemptDocId,
        studentId: attempt.studentId,
        examId: attempt.examId,
        courseId: attempt.courseId,
        startedAt: attempt.startedAt,
        submittedAt: attempt.submittedAt,
        durationSecondsUsed: attempt.durationSecondsUsed,
        answers: attempt.answers,
        correctCount: attempt.correctCount,
        incorrectCount: attempt.incorrectCount,
        score: attempt.score,
        percentage: attempt.percentage,
        attemptNumber: attempt.attemptNumber,
        isPassed: attempt.isPassed,
      );

      await docRef.set(modelToSave.toMap());
      return modelToSave;
    } catch (e) {
      throw ServerException('Failed to submit exam attempt: $e');
    }
  }

  @override
  Future<List<ExamAttemptModel>> getAttemptsForStudent(
    String studentId, {
    String? courseId,
  }) async {
    try {
      Query query = _firestore
          .collection(FirestoreCollections.examAttempts)
          .where('studentId', isEqualTo: studentId);

      if (courseId != null) {
        query = query.where('courseId', isEqualTo: courseId);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((d) => ExamAttemptModel.fromFirestore(d))
          .toList();
    } catch (e) {
      throw ServerException('Failed to load student attempts: $e');
    }
  }

  @override
  Future<List<ExamAttemptModel>> getAttemptsForExam(String examId) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.examAttempts)
              .where('examId', isEqualTo: examId)
              .get();

      return snapshot.docs
          .map((d) => ExamAttemptModel.fromFirestore(d))
          .toList();
    } catch (e) {
      throw ServerException('Failed to load exam attempts: $e');
    }
  }

  @override
  Future<List<QuestionModel>> getQuestionBank({
    String? courseId,
    String? topic,
    String? difficulty,
  }) async {
    try {
      Query query = _firestore.collection(FirestoreCollections.questionBank);
      if (courseId != null)
        query = query.where('courseId', isEqualTo: courseId);
      if (difficulty != null)
        query = query.where('difficulty', isEqualTo: difficulty);

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (d) => QuestionModel.fromMap(
              d.data() as Map<String, dynamic>,
              id: d.id,
            ),
          )
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch question bank: $e');
    }
  }

  @override
  Future<void> saveQuestionsToBank(List<QuestionModel> questions) async {
    try {
      final batch = _firestore.batch();
      for (final q in questions) {
        final doc =
            _firestore.collection(FirestoreCollections.questionBank).doc();
        batch.set(doc, q.toMap());
      }
      await batch.commit();
    } catch (e) {
      throw ServerException('Failed to save questions to bank: $e');
    }
  }
}

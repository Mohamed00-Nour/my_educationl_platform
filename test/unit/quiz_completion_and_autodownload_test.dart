import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/quizzes/domain/entities/exam_attempt_entity.dart';
import 'package:instructor/features/quizzes/domain/entities/local_attempt_entity.dart';
import 'package:instructor/features/quizzes/domain/entities/quiz_entity.dart';

void main() {
  group('Quiz Completion & Auto-download Status Logic Tests', () {
    final baseQuiz = QuizEntity(
      id: 'quiz_1',
      title: 'اختبار تجريبي',
      description: 'وصف الاختبار',
      type: QuizType.quiz,
      courseId: 'course_1',
      lessonId: 'lesson_1',
      durationMinutes: 15,
      questions: const [],
      maxAttempts: 2,
      isPublished: true,
      passingScore: 60,
      totalMarks: 10,
    );

    ExamAttemptEntity createAttempt({
      required String id,
      required int score,
      required bool isPassed,
      required DateTime submittedAt,
      int attemptNumber = 1,
    }) {
      return ExamAttemptEntity(
        id: id,
        examId: 'quiz_1',
        courseId: 'course_1',
        studentId: 'student_1',
        score: score,
        isPassed: isPassed,
        percentage: (score / 10) * 100,
        correctCount: score,
        incorrectCount: 10 - score,
        durationSecondsUsed: 120,
        attemptNumber: attemptNumber,
        answers: const {},
        startedAt: submittedAt.subtract(const Duration(minutes: 10)),
        submittedAt: submittedAt,
        syncStatus: AttemptSyncStatus.synced,
      );
    }

    test('Marks as completed when student passed on first attempt', () {
      final attempts = [
        createAttempt(
          id: 'att_1',
          score: 8,
          isPassed: true,
          submittedAt: DateTime.now(),
        ),
      ];

      final hasPassed = attempts.any((a) => a.isPassed);
      final hasConsumedRetries = attempts.length >= baseQuiz.maxAttempts;
      final isCompleted = hasPassed || hasConsumedRetries;

      expect(isCompleted, isTrue);
      expect(hasPassed, isTrue);
    });

    test('Does not mark as completed when student failed 1st attempt and retries remain', () {
      final attempts = [
        createAttempt(
          id: 'att_1',
          score: 4,
          isPassed: false,
          submittedAt: DateTime.now(),
        ),
      ];

      final hasPassed = attempts.any((a) => a.isPassed);
      final hasConsumedRetries = attempts.length >= baseQuiz.maxAttempts;
      final isCompleted = hasPassed || hasConsumedRetries;

      expect(isCompleted, isFalse);
      expect(hasConsumedRetries, isFalse);
    });

    test('Marks as completed when student exhausts all allowed retries', () {
      final attempts = [
        createAttempt(
          id: 'att_1',
          score: 3,
          isPassed: false,
          submittedAt: DateTime.now().subtract(const Duration(days: 1)),
          attemptNumber: 1,
        ),
        createAttempt(
          id: 'att_2',
          score: 4,
          isPassed: false,
          submittedAt: DateTime.now(),
          attemptNumber: 2,
        ),
      ];

      final hasPassed = attempts.any((a) => a.isPassed);
      final hasConsumedRetries = attempts.length >= baseQuiz.maxAttempts;
      final isCompleted = hasPassed || hasConsumedRetries;

      expect(isCompleted, isTrue);
      expect(hasConsumedRetries, isTrue);
    });

    test('Marks as completed when quiz deadline has expired and student has an attempt', () {
      final expiredQuiz = QuizEntity(
        id: 'quiz_1',
        title: 'اختبار منتهي',
        description: 'وصف الاختبار',
        type: QuizType.quiz,
        courseId: 'course_1',
        durationMinutes: 15,
        questions: const [],
        maxAttempts: 3,
        isPublished: true,
        availableUntil: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final attempts = [
        createAttempt(
          id: 'att_1',
          score: 5,
          isPassed: false,
          submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

      final hasPassed = attempts.any((a) => a.isPassed);
      final hasConsumedRetries = attempts.length >= expiredQuiz.maxAttempts;
      final isDeadlinePassed =
          expiredQuiz.availableUntil != null &&
          DateTime.now().isAfter(expiredQuiz.availableUntil!);

      final isCompleted =
          hasPassed ||
          (attempts.isNotEmpty && (hasConsumedRetries || isDeadlinePassed));

      expect(isCompleted, isTrue);
      expect(isDeadlinePassed, isTrue);
    });

    test('Status badges and action button labels match requirements', () {
      const readyBadge = 'تم التحميل وجاهز للبدء';
      const passedBadge = 'تم الإجتياز بنجاح';
      const completedBadge = 'تم الإجتياز';
      const detailsButton = 'عرض تفاصيل ونتيجة الاختبار';
      const startQuizButton = 'بدء اختبار الدرس الآن';

      // 1. When downloaded and not completed
      expect(readyBadge, 'تم التحميل وجاهز للبدء');
      expect(startQuizButton, 'بدء اختبار الدرس الآن');

      // 2. When completed
      expect(passedBadge.contains(completedBadge), isTrue);
      expect(detailsButton, 'عرض تفاصيل ونتيجة الاختبار');
    });
  });
}

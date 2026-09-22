import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/quizzes/domain/entities/quiz_entity.dart';
import 'package:instructor/features/quizzes/domain/services/student_quiz_listing.dart';

void main() {
  final older = DateTime.utc(2026, 9, 1);
  final newer = DateTime.utc(2026, 9, 20);

  QuizEntity quiz({
    required String id,
    required String title,
    required QuizType type,
    DateTime? createdAt,
    String description = '',
    bool isPublished = true,
  }) => QuizEntity(
    id: id,
    title: title,
    description: description,
    type: type,
    courseId: 'course',
    createdAt: createdAt,
    isPublished: isPublished,
  );

  final quizzes = [
    quiz(id: 'old', title: 'اختبار قديم', type: QuizType.quiz, createdAt: older),
    quiz(
      id: 'new',
      title: 'اختبار حديث',
      type: QuizType.quiz,
      createdAt: newer,
      description: 'البرمجة',
    ),
    quiz(id: 'exam', title: 'امتحان شامل', type: QuizType.fullExam),
    quiz(
      id: 'draft',
      title: 'مسودة',
      type: QuizType.quiz,
      createdAt: newer.add(const Duration(days: 1)),
      isPublished: false,
    ),
  ];

  test('shows newest published quizzes first and puts undated quizzes last', () {
    final result = listStudentQuizzes(
      quizzes: quizzes,
      attemptedQuizIds: const {},
    );

    expect(result.map((quiz) => quiz.id), ['new', 'old', 'exam']);
  });

  test('filters new and completed quizzes using submitted attempts', () {
    final newItems = listStudentQuizzes(
      quizzes: quizzes,
      attemptedQuizIds: const {'old'},
      filter: StudentQuizFilter.newItems,
    );
    final completed = listStudentQuizzes(
      quizzes: quizzes,
      attemptedQuizIds: const {'old'},
      filter: StudentQuizFilter.completed,
    );

    expect(newItems.map((quiz) => quiz.id), ['new', 'exam']);
    expect(completed.map((quiz) => quiz.id), ['old']);
  });

  test('filters by quiz type and searches title or description', () {
    final exams = listStudentQuizzes(
      quizzes: quizzes,
      attemptedQuizIds: const {},
      filter: StudentQuizFilter.fullExams,
    );
    final search = listStudentQuizzes(
      quizzes: quizzes,
      attemptedQuizIds: const {},
      filter: StudentQuizFilter.shortQuizzes,
      searchQuery: 'البرمجة',
    );

    expect(exams.map((quiz) => quiz.id), ['exam']);
    expect(search.map((quiz) => quiz.id), ['new']);
  });
}

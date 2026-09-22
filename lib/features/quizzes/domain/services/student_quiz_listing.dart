import '../entities/quiz_entity.dart';

enum StudentQuizFilter { all, newItems, completed, shortQuizzes, fullExams }

/// Returns published quizzes in creation order, newest first. "New" means the
/// student has not submitted an attempt yet.
List<QuizEntity> listStudentQuizzes({
  required Iterable<QuizEntity> quizzes,
  required Set<String> attemptedQuizIds,
  StudentQuizFilter filter = StudentQuizFilter.all,
  String searchQuery = '',
}) {
  final query = searchQuery.trim().toLowerCase();
  final results = quizzes.where((quiz) {
    if (!quiz.isPublished) return false;
    if (query.isNotEmpty &&
        !quiz.title.toLowerCase().contains(query) &&
        !quiz.description.toLowerCase().contains(query)) {
      return false;
    }
    switch (filter) {
      case StudentQuizFilter.all:
        return true;
      case StudentQuizFilter.newItems:
        return !attemptedQuizIds.contains(quiz.id);
      case StudentQuizFilter.completed:
        return attemptedQuizIds.contains(quiz.id);
      case StudentQuizFilter.shortQuizzes:
        return quiz.type == QuizType.quiz;
      case StudentQuizFilter.fullExams:
        return quiz.type == QuizType.fullExam;
    }
  }).toList();

  results.sort((a, b) {
    final aDate = a.createdAt;
    final bDate = b.createdAt;
    if (aDate == null && bDate != null) return 1;
    if (aDate != null && bDate == null) return -1;
    if (aDate != null && bDate != null) {
      final dateOrder = bDate.compareTo(aDate);
      if (dateOrder != 0) return dateOrder;
    }
    final titleOrder = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    return titleOrder != 0 ? titleOrder : a.id.compareTo(b.id);
  });
  return results;
}

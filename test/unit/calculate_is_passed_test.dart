import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/quizzes/domain/entities/quiz_entity.dart';

void main() {
  group('QuizEntity.calculateIsPassed Tests', () {
    test('User issue reproduction: 3 out of 3 marks with 60% passingScore passes', () {
      final passed = QuizEntity.calculateIsPassed(
        score: 3,
        totalMarks: 3,
        passingScore: 60,
      );
      expect(passed, isTrue);
    });

    test('3 marks quiz: 2 out of 3 marks (66.7%) with 60% passingScore passes', () {
      final passed = QuizEntity.calculateIsPassed(
        score: 2,
        totalMarks: 3,
        passingScore: 60,
      );
      expect(passed, isTrue);
    });

    test('3 marks quiz: 1 out of 3 marks (33.3%) with 60% passingScore fails', () {
      final passed = QuizEntity.calculateIsPassed(
        score: 1,
        totalMarks: 3,
        passingScore: 60,
      );
      expect(passed, isFalse);
    });

    test('3 marks quiz: 0 out of 3 marks with 60% passingScore fails', () {
      final passed = QuizEntity.calculateIsPassed(
        score: 0,
        totalMarks: 3,
        passingScore: 60,
      );
      expect(passed, isFalse);
    });

    test('Raw score threshold: 6 out of 10 marks with 6 passingScore passes', () {
      final passed = QuizEntity.calculateIsPassed(
        score: 6,
        totalMarks: 10,
        passingScore: 6,
      );
      expect(passed, isTrue);
    });

    test('Raw score threshold: 5 out of 10 marks with 6 passingScore fails', () {
      final passed = QuizEntity.calculateIsPassed(
        score: 5,
        totalMarks: 10,
        passingScore: 6,
      );
      expect(passed, isFalse);
    });

    test('Large quiz: 100 questions with 60% passingScore passes at 60 and fails at 59', () {
      expect(
        QuizEntity.calculateIsPassed(score: 60, totalMarks: 100, passingScore: 60),
        isTrue,
      );
      expect(
        QuizEntity.calculateIsPassed(score: 59, totalMarks: 100, passingScore: 60),
        isFalse,
      );
    });

    test('Edge case: totalMarks is 0 or passingScore <= 0 returns true', () {
      expect(
        QuizEntity.calculateIsPassed(score: 0, totalMarks: 0, passingScore: 60),
        isTrue,
      );
      expect(
        QuizEntity.calculateIsPassed(score: 0, totalMarks: 10, passingScore: 0),
        isTrue,
      );
    });
  });
}

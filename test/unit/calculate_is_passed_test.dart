import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/utils/performance_rating.dart';
import 'package:instructor/features/quizzes/domain/entities/quiz_entity.dart';

void main() {
  group('Unified quiz and exam performance policy', () {
    test('less than 50% needs practice and does not pass', () {
      final rating = PerformanceRating.fromPercentage(49.9);

      expect(rating.band, PerformanceBand.needsPractice);
      expect(rating.isSuccessful, isFalse);
      expect(
        QuizEntity.calculateIsPassed(
          score: 49,
          totalMarks: 100,
          passingScore: 100,
        ),
        isFalse,
      );
    });

    test('50% through less than 90% is good and successful', () {
      final lowerBoundary = PerformanceRating.fromPercentage(50);
      final studentExample = PerformanceRating.fromPercentage(88);

      expect(lowerBoundary.band, PerformanceBand.good);
      expect(studentExample.band, PerformanceBand.good);
      expect(studentExample.isSuccessful, isTrue);
      expect(
        QuizEntity.calculateIsPassed(
          score: 88,
          totalMarks: 100,
          passingScore: 100,
        ),
        isTrue,
      );
    });

    test('90% through less than 100% is very good and successful', () {
      expect(
        PerformanceRating.fromPercentage(90).band,
        PerformanceBand.veryGood,
      );
      expect(
        PerformanceRating.fromPercentage(99.99).band,
        PerformanceBand.veryGood,
      );
    });

    test('exactly 100% is excellent', () {
      final rating = PerformanceRating.fromPercentage(100);

      expect(rating.band, PerformanceBand.excellent);
      expect(rating.isExcellent, isTrue);
      expect(rating.labelArabic, 'ممتاز');
    });

    test('percentage is calculated correctly for non-100 total marks', () {
      final rating = PerformanceRating.fromScore(score: 2, totalMarks: 3);

      expect(rating.percentage, closeTo(66.67, 0.01));
      expect(rating.band, PerformanceBand.good);
      expect(
        QuizEntity.calculateIsPassed(score: 2, totalMarks: 3, passingScore: 60),
        isTrue,
      );
    });

    test('invalid totals fail safely and percentages are clamped', () {
      expect(
        QuizEntity.calculateIsPassed(score: 0, totalMarks: 0, passingScore: 0),
        isFalse,
      );
      expect(PerformanceRating.fromPercentage(-5).percentage, 0);
      expect(PerformanceRating.fromPercentage(120).percentage, 100);
    });
  });
}

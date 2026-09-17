enum PerformanceBand { needsPractice, good, veryGood, excellent }

/// One consistent percentage policy for quizzes, exams, progress, and reports.
class PerformanceRating {
  static const double passThreshold = 50.0;
  static const double veryGoodThreshold = 90.0;
  static const double excellentThreshold = 100.0;

  final double percentage;
  final PerformanceBand band;

  const PerformanceRating._({required this.percentage, required this.band});

  factory PerformanceRating.fromPercentage(num value) {
    final percentage = value.toDouble().clamp(0.0, 100.0);
    final band =
        percentage >= excellentThreshold
            ? PerformanceBand.excellent
            : percentage >= veryGoodThreshold
            ? PerformanceBand.veryGood
            : percentage >= passThreshold
            ? PerformanceBand.good
            : PerformanceBand.needsPractice;
    return PerformanceRating._(percentage: percentage, band: band);
  }

  factory PerformanceRating.fromScore({
    required num score,
    required num totalMarks,
  }) {
    if (totalMarks <= 0) return PerformanceRating.fromPercentage(0);
    return PerformanceRating.fromPercentage(score / totalMarks * 100.0);
  }

  bool get isSuccessful => band != PerformanceBand.needsPractice;
  bool get isVeryGood => band == PerformanceBand.veryGood;
  bool get isExcellent => band == PerformanceBand.excellent;

  String get labelArabic {
    switch (band) {
      case PerformanceBand.needsPractice:
        return 'يحتاج إلى مزيد من التدريب';
      case PerformanceBand.good:
        return 'جيد';
      case PerformanceBand.veryGood:
        return 'جيد جداً';
      case PerformanceBand.excellent:
        return 'ممتاز';
    }
  }

  String get resultMessageArabic {
    switch (band) {
      case PerformanceBand.needsPractice:
        return 'استمر في التدريب وستتحسن نتيجتك';
      case PerformanceBand.good:
        return 'أداء جيد، ومع بعض العمل ستصل لمستوى أعلى';
      case PerformanceBand.veryGood:
        return 'أداء رائع ومستوى متميز';
      case PerformanceBand.excellent:
        return 'نتيجة كاملة وأداء ممتاز';
    }
  }
}

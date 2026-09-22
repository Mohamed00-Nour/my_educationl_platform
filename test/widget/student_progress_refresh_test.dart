import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/services/service_locator.dart';
import 'package:instructor/features/progress/domain/entities/student_progress_summary.dart';
import 'package:instructor/features/progress/domain/repositories/progress_repository.dart';
import 'package:instructor/features/progress/presentation/screens/student_progress_screen.dart';

class _ProgressRepositoryFake implements ProgressRepository {
  int requestCount = 0;
  final List<bool> forceRefreshValues = [];

  @override
  Future<StudentProgressSummary> getStudentProgressSummary({
    required String studentId,
    required String studentName,
    required String courseId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    requestCount++;
    forceRefreshValues.add(forceRefresh);
    return StudentProgressSummary(
      studentId: studentId,
      studentName: studentName,
      courseId: courseId,
      finalCompositeScore: requestCount == 1 ? 20 : 80,
      lastUpdated: DateTime.now(),
    );
  }
}

void main() {
  testWidgets('refresh button fetches and displays updated progress', (
    tester,
  ) async {
    final repository = _ProgressRepositoryFake();
    getIt.registerSingleton<ProgressRepository>(repository);
    addTearDown(() => getIt.unregister<ProgressRepository>());

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentProgressScreen(
          studentId: 'student-1',
          studentName: 'Student',
          courseId: 'course-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20.0%'), findsOneWidget);
    await tester.tap(find.byTooltip('تحديث البيانات'));
    await tester.pumpAndSettle();

    expect(find.text('80.0%'), findsOneWidget);
    expect(repository.requestCount, 2);
    expect(repository.forceRefreshValues, [true, true]);
  });
}

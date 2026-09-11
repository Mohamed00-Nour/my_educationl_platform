import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/constants/app_constants.dart';
import 'package:instructor/core/widgets/app_button.dart';
import 'package:instructor/core/widgets/status_badge.dart';

void main() {
  testWidgets('AppButton renders and triggers callback', (
    WidgetTester tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'بدء الاختبار',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('بدء الاختبار'), findsOneWidget);
    await tester.tap(find.text('بدء الاختبار'));
    await tester.pump();

    expect(tapped, true);
  });

  testWidgets(
    '3D Duolingo buttons render in unconstrained horizontal SingleChildScrollView without size.isFinite crash',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppButton(
                    label: 'زر 1',
                    width: 100,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'زر 2',
                    width: 120,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('زر 1'), findsOneWidget);
      expect(find.text('زر 2'), findsOneWidget);
      await tester.tap(find.text('زر 1'));
      await tester.pump();
    },
  );

  testWidgets(
    'StatusBadge renders Arabic difficulty and attendance badges correctly',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.difficulty('hard'),
                StatusBadge.difficulty('easy'),
                StatusBadge.present(),
                StatusBadge.absent(),
                StatusBadge.bonus('+5 مكافأة'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('صعب'), findsOneWidget);
      expect(find.text('سهل'), findsOneWidget);
      expect(find.text('حاضر'), findsOneWidget);
      expect(find.text('غائب'), findsOneWidget);
      expect(find.text('+5 مكافأة'), findsOneWidget);
    },
  );

  group('StudentGrade Model Tests', () {
    test('correctly maps strings to enum', () {
      expect(
        StudentGrade.fromString('firstSecondary'),
        StudentGrade.firstSecondary,
      );
      expect(
        StudentGrade.fromString('secondSecondary'),
        StudentGrade.secondSecondary,
      );
      expect(
        StudentGrade.fromString('أولى ثانوي'),
        StudentGrade.firstSecondary,
      );
      expect(
        StudentGrade.fromString('تانية ثانوي'),
        StudentGrade.secondSecondary,
      );
      expect(
        StudentGrade.fromString('الصف الأول الثانوي'),
        StudentGrade.firstSecondary,
      );
      expect(
        StudentGrade.fromString('الصف الثاني الثانوي'),
        StudentGrade.secondSecondary,
      );
    });

    test('correctly outputs Arabic displays', () {
      expect(StudentGrade.firstSecondary.toArabicDisplay(), 'أولى ثانوي');
      expect(StudentGrade.secondSecondary.toArabicDisplay(), 'تانية ثانوي');
      expect(
        StudentGrade.firstSecondary.toFormalArabic(),
        'الصف الأول الثانوي',
      );
      expect(
        StudentGrade.secondSecondary.toFormalArabic(),
        'الصف الثاني الثانوي',
      );
    });
  });
}

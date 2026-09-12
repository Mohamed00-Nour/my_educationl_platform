import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/widgets/responsive_layout.dart';

void main() {
  group('Responsive Breakpoints & Context Tests', () {
    testWidgets('identifies mobile screens (< 650px)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late DeviceScreenType screenType;
      late bool isMobile;
      late bool isTablet;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              screenType = context.screenType;
              isMobile = context.isMobile;
              isTablet = context.isTablet;
              isDesktop = context.isDesktop;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(screenType, DeviceScreenType.mobile);
      expect(isMobile, isTrue);
      expect(isTablet, isFalse);
      expect(isDesktop, isFalse);
    });

    testWidgets('identifies tablet screens (650px - 1099px)', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late DeviceScreenType screenType;
      late bool isMobile;
      late bool isTablet;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              screenType = context.screenType;
              isMobile = context.isMobile;
              isTablet = context.isTablet;
              isDesktop = context.isDesktop;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(screenType, DeviceScreenType.tablet);
      expect(isMobile, isFalse);
      expect(isTablet, isTrue);
      expect(isDesktop, isFalse);
    });

    testWidgets('identifies desktop screens (>= 1100px)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late DeviceScreenType screenType;
      late bool isMobile;
      late bool isTablet;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              screenType = context.screenType;
              isMobile = context.isMobile;
              isTablet = context.isTablet;
              isDesktop = context.isDesktop;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(screenType, DeviceScreenType.desktop);
      expect(isMobile, isFalse);
      expect(isTablet, isFalse);
      expect(isDesktop, isTrue);
    });

    testWidgets('ResponsiveContent limits child width to maxWidth', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContent(
              maxWidth: 900,
              child: SizedBox(
                key: Key('child_box'),
                width: double.infinity,
                height: 200,
              ),
            ),
          ),
        ),
      );

      final childBox = tester.getRect(find.byKey(const Key('child_box')));
      expect(childBox.width, 900.0);
      expect(childBox.top, 0.0);
    });
  });
}

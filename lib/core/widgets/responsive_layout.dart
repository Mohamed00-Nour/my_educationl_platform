import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Screen size breakpoints for Mobile, Tablet, and Windows Desktop.
abstract class AppBreakpoints {
  static const double mobileMax = 650.0;
  static const double tabletMax = 1100.0;

  /// Standard max content widths for ergonomic centering
  static const double maxContentWidth = 1100.0;
  static const double maxNarrowContentWidth = 720.0;
  static const double maxReadingContentWidth = 850.0;
}

/// Device classification based on viewport width
enum DeviceScreenType {
  mobile,
  tablet,
  desktop,
}

/// Helpful responsive extensions on [BuildContext]
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  DeviceScreenType get screenType {
    final width = screenWidth;
    if (width < AppBreakpoints.mobileMax) {
      return DeviceScreenType.mobile;
    } else if (width < AppBreakpoints.tabletMax) {
      return DeviceScreenType.tablet;
    } else {
      return DeviceScreenType.desktop;
    }
  }

  bool get isMobile => screenType == DeviceScreenType.mobile;
  bool get isTablet => screenType == DeviceScreenType.tablet;
  bool get isDesktop => screenType == DeviceScreenType.desktop;
  bool get isDesktopOrTablet => !isMobile;

  /// Responsive padding for standard screen layouts
  EdgeInsets get screenPadding {
    if (isMobile) {
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0);
    } else if (isTablet) {
      return const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0);
    }
  }

  /// Select value based on active device screen type
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    if (isDesktop && tablet != null) return tablet;
    return mobile;
  }
}

/// A container widget that centers its child with an ergonomic maximum width
/// on wide screens (Tablets & Windows Desktop), preventing awkward horizontal stretching.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    return Align(
      alignment: alignment,
      child: content,
    );
  }
}

/// Shows a bottom sheet on Mobile, and a centered dialog on Tablet & Windows Desktop.
Future<T?> showAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 580.0,
  bool isDismissible = true,
  Color? backgroundColor,
}) {
  if (context.isMobile) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor ?? AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: builder(ctx),
        ),
      ),
    );
  } else {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => Dialog(
        backgroundColor: backgroundColor ?? AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        elevation: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: builder(ctx),
          ),
        ),
      ),
    );
  }
}

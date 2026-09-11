import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Iconic Duolingo-style Tactile 3D Button.
/// Features a chunky 3D bottom bevel with a tactile push-down animation on tap.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final double fontSize;
  final double bevelHeight;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 50,
    this.borderRadius = 16,
    this.fontSize = 15,
    this.bevelHeight = 4.0,
    this.padding,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  Color _resolveBevelColor(Color bg) {
    if (bg == AppColors.primary) return AppColors.primaryDark;
    if (bg == AppColors.secondary) return AppColors.secondaryDark;
    if (bg == AppColors.error) return AppColors.errorDark;
    if (bg == AppColors.warning || bg == AppColors.bonus)
      return AppColors.warningDark;
    if (bg == AppColors.accent) return AppColors.accentDark;
    if (bg == AppColors.orange) return AppColors.orangeDark;
    // For custom colors, darken by 25%
    return HSLColor.fromColor(bg)
        .withLightness(
          (HSLColor.fromColor(bg).lightness * 0.75).clamp(0.0, 1.0),
        )
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;

    Color bg;
    Color bevel;
    Color text;

    if (!isEnabled) {
      bg = AppColors.surfaceElevated;
      bevel = AppColors.borderDark;
      text = AppColors.textMuted;
    } else if (widget.isOutlined) {
      bg = AppColors.surface;
      bevel = AppColors.borderDark;
      text = widget.textColor ?? widget.backgroundColor ?? AppColors.secondary;
    } else {
      bg = widget.backgroundColor ?? AppColors.primary;
      bevel = _resolveBevelColor(bg);
      text =
          widget.textColor ??
          (bg == AppColors.primary ? const Color(0xFF131F24) : Colors.white);
    }

    final double pressOffset =
        (_isPressed && isEnabled) ? (widget.bevelHeight * 0.75) : 0.0;
    final double bevelHeight = widget.bevelHeight;
    final double faceHeight = widget.height - bevelHeight;

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp:
            isEnabled
                ? (_) {
                  setState(() => _isPressed = false);
                  widget.onPressed?.call();
                }
                : null,
        onTapCancel:
            isEnabled ? () => setState(() => _isPressed = false) : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 3D Bottom Bevel Layer
            Positioned(
              top: bevelHeight,
              left: 0,
              right: 0,
              height: faceHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: bevel,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
              ),
            ),
            // Tactile Top Face Layer (Non-positioned child)
            AnimatedSlide(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOut,
              offset: Offset(
                0,
                (_isPressed && isEnabled) ? (pressOffset / faceHeight) : 0.0,
              ),
              child: Container(
                height: faceHeight,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border:
                      widget.isOutlined
                          ? Border.all(
                            color:
                                isEnabled
                                    ? (widget.backgroundColor ??
                                        AppColors.border)
                                    : AppColors.borderDark,
                            width: 2,
                          )
                          : null,
                ),
                alignment: Alignment.center,
                padding:
                    widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 16),
                child:
                    widget.isLoading
                        ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(text),
                          ),
                        )
                        : Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, size: widget.fontSize + 4, color: text),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                widget.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: text,
                                  fontWeight: FontWeight.w800,
                                  fontSize: widget.fontSize,
                                  fontFamily: 'Cairo',
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

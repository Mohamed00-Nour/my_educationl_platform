import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Duolingo Gaming-Style Status & Evaluation Badge.
/// Rendered as chunky pills with bold 2px borders and glowing status accents.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.icon,
  });

  factory StatusBadge.present() {
    return const StatusBadge(
      label: 'حاضر',
      backgroundColor: AppColors.successLight,
      textColor: AppColors.present,
      borderColor: AppColors.present,
      icon: Icons.check_circle_rounded,
    );
  }

  factory StatusBadge.absent() {
    return const StatusBadge(
      label: 'غائب',
      backgroundColor: AppColors.errorLight,
      textColor: AppColors.absent,
      borderColor: AppColors.absent,
      icon: Icons.cancel_rounded,
    );
  }

  factory StatusBadge.late() {
    return const StatusBadge(
      label: 'متأخر',
      backgroundColor: AppColors.orangeLight,
      textColor: AppColors.late,
      borderColor: AppColors.late,
      icon: Icons.alarm_rounded,
    );
  }

  factory StatusBadge.bonus([String? text]) {
    return StatusBadge(
      label: text ?? 'مكافأة',
      backgroundColor: AppColors.warningLight,
      textColor: AppColors.bonus,
      borderColor: AppColors.bonus,
      icon: Icons.star_rounded,
    );
  }

  factory StatusBadge.minus([String? text]) {
    return StatusBadge(
      label: text ?? 'خصم',
      backgroundColor: AppColors.errorLight,
      textColor: AppColors.minus,
      borderColor: AppColors.minus,
      icon: Icons.remove_circle_rounded,
    );
  }

  factory StatusBadge.difficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const StatusBadge(
          label: 'سهل',
          backgroundColor: AppColors.successLight,
          textColor: AppColors.success,
          borderColor: AppColors.success,
          icon: Icons.bolt_rounded,
        );
      case 'hard':
        return const StatusBadge(
          label: 'صعب',
          backgroundColor: AppColors.errorLight,
          textColor: AppColors.error,
          borderColor: AppColors.error,
          icon: Icons.whatshot_rounded,
        );
      case 'medium':
      default:
        return const StatusBadge(
          label: 'متوسط',
          backgroundColor: AppColors.warningLight,
          textColor: AppColors.warning,
          borderColor: AppColors.warning,
          icon: Icons.tune_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? textColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

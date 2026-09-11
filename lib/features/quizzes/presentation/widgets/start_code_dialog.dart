import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/quiz_entity.dart';

class StartCodeDialog extends StatefulWidget {
  final QuizEntity quiz;

  const StartCodeDialog({super.key, required this.quiz});

  /// Displays the Start Code dialog. Returns the entered code on success, or `null` if cancelled.
  /// If the quiz does not require a start code, returns an empty string `''`.
  static Future<String?> show(BuildContext context, QuizEntity quiz) async {
    if (!quiz.requireStartCode) {
      return '';
    }
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StartCodeDialog(quiz: quiz),
    );
    return result;
  }

  @override
  State<StartCodeDialog> createState() => _StartCodeDialogState();
}

class _StartCodeDialogState extends State<StartCodeDialog> {
  final _codeController = TextEditingController();
  String? _errorMessage;
  bool _isChecking = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _validateAndProceed() {
    final enteredCode = _codeController.text.trim();
    if (enteredCode.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال رمز بدء الاختبار';
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    // Offline validation using secure hash and salt
    final isValid = widget.quiz.validateStartCode(enteredCode);

    if (isValid) {
      Navigator.of(context).pop(enteredCode);
    } else {
      setState(() {
        _isChecking = false;
        _errorMessage = 'رمز البدء غير صحيح، يرجى مراجعة المعلم';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExam = widget.quiz.isFullExam;
    final assessmentTitle = isExam ? 'الامتحان الشامل' : 'الاختبار';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon header
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_outlined,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'رمز بدء $assessmentTitle',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'هذا $assessmentTitle محمي برمز بدء. اطلب الرمز المكون من 6 أرقام من معلم الفصل للبدء.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Code Input Field
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
              decoration: InputDecoration(
                hintText: '••••••',
                counterText: '',
                errorText: _errorMessage,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) => _validateAndProceed(),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'بدء الآن',
                    isLoading: _isChecking,
                    onPressed: _validateAndProceed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}

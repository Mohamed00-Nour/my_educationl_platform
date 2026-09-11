import 'package:flutter/material.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/services/attempt_sync_service.dart';
import '../../domain/entities/exam_attempt_entity.dart';
import '../../domain/entities/local_attempt_entity.dart';
import '../../domain/entities/quiz_entity.dart';

class ExamResultScreen extends StatefulWidget {
  final ExamAttemptEntity attempt;
  final QuizEntity quiz;
  final bool wasAutoSubmitted;

  const ExamResultScreen({
    super.key,
    required this.attempt,
    required this.quiz,
    this.wasAutoSubmitted = false,
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  late AttemptSyncStatus _syncStatus;
  bool _isRetryingSync = false;

  @override
  void initState() {
    super.initState();
    _syncStatus = widget.attempt.syncStatus;
  }

  Future<void> _manualSync() async {
    setState(() => _isRetryingSync = true);
    try {
      final syncService = getIt<AttemptSyncService>();
      final count = await syncService.syncPendingAttempts();
      if (mounted) {
        if (count > 0) {
          setState(() => _syncStatus = AttemptSyncStatus.synced);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تمت مزامنة نتيجة الاختبار بنجاح مع السحابة!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'النتيجة محفوظة بأمان على جهازك. سيتم رفعها تلقائياً فور توفر الإنترنت.',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('النتيجة محفوظة محلياً. ستتم إعادة المحاولة لاحقاً.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRetryingSync = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    final attempt = widget.attempt;
    final wasAutoSubmitted = widget.wasAutoSubmitted;
    final bool canShowExplanations = quiz.canShowExplanationsNow;
    final bool canShowCorrectAnswers = quiz.showCorrectAnswers;

    final isSynced = _syncStatus == AttemptSyncStatus.synced;

    final effectiveTotalMarks =
        quiz.totalMarks > 0
            ? quiz.totalMarks
            : (quiz.questions.isNotEmpty
                ? quiz.questions.fold<int>(0, (s, q) => s + q.marks)
                : (attempt.score > 0 ? attempt.score : 1));

    final effectivePassed =
        attempt.isPassed ||
        QuizEntity.calculateIsPassed(
          score: attempt.score,
          totalMarks: effectiveTotalMarks,
          passingScore: quiz.passingScore,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          quiz.isFullExam ? 'نتيجة الامتحان الشامل' : 'نتيجة الاختبار',
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'إغلاق',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ResponsiveContent(
        maxWidth: 820,
        child: SingleChildScrollView(
          padding: context.screenPadding,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cloud Sync Status Banner
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isSynced ? AppColors.successLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSynced
                          ? AppColors.success.withAlpha(80)
                          : AppColors.warning.withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSynced
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_queue_rounded,
                    color: isSynced ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isSynced
                          ? 'تمت المزامنة وحفظ النتيجة في السحابة بنجاح'
                          : 'النتيجة محفوظة بأمان على جهازك - بانتظار المزامنة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSynced ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                  if (!isSynced)
                    _isRetryingSync
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : TextButton(
                          onPressed: _manualSync,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'مزامنة الآن',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                ],
              ),
            ),

            // Auto Submit Banner if triggered by timer
            if (wasAutoSubmitted)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.timer_off_outlined,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'انتهى الوقت المحدد! تم تسليم اختبارك تلقائياً.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Performance Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color:
                            effectivePassed
                                ? AppColors.successLight
                                : AppColors.errorLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        effectivePassed
                            ? Icons.emoji_events_outlined
                            : Icons.sentiment_dissatisfied_outlined,
                        size: 48,
                        color:
                            effectivePassed
                                ? AppColors.success
                                : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      effectivePassed
                          ? 'تهانينا! لقد اجتزت الاختبار بنجاح'
                          : 'تحتاج إلى مزيد من التدريب والمذاكرة',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quiz.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Metrics Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MetricItem(
                          label: 'الدرجة',
                          value: '${attempt.score} / $effectiveTotalMarks',
                          color: AppColors.primary,
                        ),
                        _MetricItem(
                          label: 'النسبة المئوية',
                          value: '${attempt.percentage}%',
                          color:
                              effectivePassed
                                  ? AppColors.success
                                  : AppColors.error,
                        ),
                        _MetricItem(
                          label: 'الوقت المستغرق',
                          value: DateTimeUtils.formatDuration(
                            attempt.durationSecondsUsed,
                          ),
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${attempt.correctCount} إجابات صحيحة',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${attempt.incorrectCount} إجابات خاطئة',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Question Review List
            if (canShowCorrectAnswers || canShowExplanations) ...[
              const Text(
                'مراجعة الأسئلة والشرح التعليمي',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(quiz.questions.length, (idx) {
                final q = quiz.questions[idx];
                final selectedAnswer = attempt.answers[q.id];
                final isCorrect =
                    selectedAnswer != null &&
                    selectedAnswer == q.correctAnswerIndex;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'السؤال ${idx + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            if (isCorrect)
                              const StatusBadge(
                                label: 'إجابة صحيحة',
                                backgroundColor: AppColors.successLight,
                                textColor: AppColors.success,
                                icon: Icons.check,
                              )
                            else
                              const StatusBadge(
                                label: 'إجابة خاطئة',
                                backgroundColor: AppColors.errorLight,
                                textColor: AppColors.error,
                                icon: Icons.close,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          q.questionText,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Options Review
                        ...List.generate(q.options.length, (optIdx) {
                          final isStudentPick = selectedAnswer == optIdx;
                          final isActualCorrect =
                              canShowCorrectAnswers &&
                              optIdx == q.correctAnswerIndex;

                          Color itemBg = Colors.transparent;
                          Color itemColor = AppColors.textSecondary;
                          IconData? icon;

                          if (isActualCorrect) {
                            itemBg = AppColors.successLight;
                            itemColor = AppColors.success;
                            icon = Icons.check_circle;
                          } else if (isStudentPick && !isCorrect) {
                            itemBg = AppColors.errorLight;
                            itemColor = AppColors.error;
                            icon = Icons.cancel;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: itemBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if (icon != null) ...[
                                  Icon(icon, size: 16, color: itemColor),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    q.options[optIdx],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          (isStudentPick || isActualCorrect)
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                      color: itemColor,
                                    ),
                                  ),
                                ),
                                if (isStudentPick)
                                  const Text(
                                    '(إجابتك)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),

                        // Educational Explanation Card
                        if (canShowExplanations &&
                            q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryLight.withAlpha(40),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'الشرح والتفسير التعليمي:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        q.explanation,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ] else ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'ستصبح الإجابات النموذجية والتفسيرات متاحة بعد انتهاء فترة الامتحان.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            AppButton(
              label: 'العودة للكورسات',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

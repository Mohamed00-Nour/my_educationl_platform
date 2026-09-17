import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/performance_rating.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/entities/exam_attempt_entity.dart';
import '../../domain/entities/quiz_entity.dart';
import '../../domain/repositories/quiz_repository.dart';

class ExamSubmissionsSheet extends StatefulWidget {
  final QuizEntity quiz;
  final bool isDialog;

  const ExamSubmissionsSheet({
    super.key,
    required this.quiz,
    this.isDialog = false,
  });

  static Future<void> show(BuildContext context, QuizEntity quiz) {
    if (context.isMobile) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ExamSubmissionsSheet(quiz: quiz),
      );
    } else {
      return showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750, maxHeight: 800),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ExamSubmissionsSheet(quiz: quiz, isDialog: true),
            ),
          ),
        ),
      );
    }
  }

  @override
  State<ExamSubmissionsSheet> createState() => _ExamSubmissionsSheetState();
}

class _ExamSubmissionsSheetState extends State<ExamSubmissionsSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ExamAttemptEntity> _attempts = [];
  final Map<String, String> _studentNames = {};
  String _filter = 'all'; // all, passed, failed

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = getIt<QuizRepository>();
      final attempts = await repo.getAttemptsForExam(widget.quiz.id);

      // Fetch student display names from Firestore
      final studentIds = attempts.map((a) => a.studentId).toSet().toList();
      if (studentIds.isNotEmpty) {
        final firestore = FirebaseFirestore.instance;
        // Firestore whereIn supports up to 30 elements per query
        for (var i = 0; i < studentIds.length; i += 30) {
          final batchIds = studentIds.skip(i).take(30).toList();
          try {
            final snap = await firestore
                .collection(FirestoreCollections.users)
                .where(FieldPath.documentId, whereIn: batchIds)
                .get();

            for (final doc in snap.docs) {
              final data = doc.data();
              final name = data['displayName'] as String?;
              if (name != null && name.trim().isNotEmpty) {
                _studentNames[doc.id] = name.trim();
              }
            }
          } catch (_) {
            // Ignore student name lookup errors, ID fallback will be used
          }
        }
      }

      if (mounted) {
        setState(() {
          _attempts = attempts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل بيانات التسليم: $e';
          _isLoading = false;
        });
      }
    }
  }

  bool _isPassed(ExamAttemptEntity a) {
    return PerformanceRating.fromScore(
      score: a.score,
      totalMarks: widget.quiz.totalMarks > 0 ? widget.quiz.totalMarks : 1,
    ).isSuccessful;
  }

  List<ExamAttemptEntity> get _filteredAttempts {
    if (_filter == 'passed') {
      return _attempts.where((a) => _isPassed(a)).toList();
    } else if (_filter == 'failed') {
      return _attempts.where((a) => !_isPassed(a)).toList();
    }
    return _attempts;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) {
      return _buildSheetContent(context);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) =>
          _buildSheetContent(context, scrollController),
    );
  }

  Widget _buildSheetContent(
    BuildContext context, [
    ScrollController? scrollController,
  ]) {
    final isExam = widget.quiz.isFullExam;
    final totalAttempts = _attempts.length;
    final passedCount = _attempts.where((a) => _isPassed(a)).length;
    final passRate =
        totalAttempts > 0 ? (passedCount / totalAttempts * 100) : 0.0;
    final avgScore = totalAttempts > 0
        ? (_attempts.fold<int>(0, (acc, a) => acc + a.score) / totalAttempts)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: widget.isDialog
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle (only when bottom sheet)
          if (!widget.isDialog)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isExam ? AppColors.accent : AppColors.primary)
                            .withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isExam ? Icons.assignment_outlined : Icons.quiz_outlined,
                        color: isExam ? AppColors.accent : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.quiz.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'نتائج ومحاولات تسليم الطلاب • الدرجة العظمى: ${widget.quiz.totalMarks}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'تحديث',
                      onPressed: _loadSubmissions,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 48, color: AppColors.error),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.error),
                                  ),
                                  const SizedBox(height: 16),
                                  AppButton(
                                    label: 'إعادة المحاولة',
                                    onPressed: _loadSubmissions,
                                    backgroundColor: AppColors.primary,
                                    height: 44,
                                    borderRadius: 12,
                                    bevelHeight: 3.5,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : totalAttempts == 0
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.assignment_late_outlined,
                                          size: 40,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'لا توجد محاولات تسليم بعد',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'لم يقم أي طالب بإجراء هذا الاختبار حتى الآن.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView(
                                controller: scrollController,
                                padding: const EdgeInsets.all(20),
                                children: [
                                  // Stats Cards
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MetricBox(
                                          label: 'إجمالي المحاولات',
                                          value: '$totalAttempts',
                                          icon: Icons.people_alt_outlined,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MetricBox(
                                          label: 'نسبة النجاح',
                                          value: '${passRate.toStringAsFixed(0)}%',
                                          icon: Icons.check_circle_outline,
                                          color: passRate >= 60
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MetricBox(
                                          label: 'متوسط الدرجات',
                                          value: avgScore.toStringAsFixed(1),
                                          icon: Icons.grade_outlined,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Filter row
                                  Row(
                                    children: [
                                      const Text(
                                        'سجل المحاولات:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      _FilterChip(
                                        label: 'الكل ($totalAttempts)',
                                        isSelected: _filter == 'all',
                                        onTap: () => setState(() => _filter = 'all'),
                                      ),
                                      const SizedBox(width: 6),
                                      _FilterChip(
                                        label: 'ناجح ($passedCount)',
                                        isSelected: _filter == 'passed',
                                        onTap: () => setState(() => _filter = 'passed'),
                                      ),
                                      const SizedBox(width: 6),
                                      _FilterChip(
                                        label: 'يحتاج تدريب (${totalAttempts - passedCount})',
                                        isSelected: _filter == 'failed',
                                        onTap: () => setState(() => _filter = 'failed'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Attempt Cards
                                  ..._filteredAttempts.map((attempt) {
                                    final performance =
                                        PerformanceRating.fromScore(
                                          score: attempt.score,
                                          totalMarks:
                                              widget.quiz.totalMarks > 0
                                                  ? widget.quiz.totalMarks
                                                  : 1,
                                        );
                                    final isPassed = performance.isSuccessful;
                                    final performanceColor =
                                        AppColors.forPerformance(
                                          performance.band,
                                        );
                                    final studentName = _studentNames[attempt.studentId] ??
                                        'طالب (${attempt.studentId.length > 6 ? attempt.studentId.substring(0, 6) : attempt.studentId})';
                                    final minutesUsed = attempt.durationSecondsUsed ~/ 60;
                                    final secondsUsed = attempt.durationSecondsUsed % 60;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: performanceColor.withAlpha(40),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Row(
                                          children: [
                                            // Status avatar
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: performanceColor.withAlpha(25),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isPassed
                                                    ? Icons.check
                                                    : Icons.close,
                                                color: performanceColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),

                                            // Student and attempt info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    studentName,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'المحاولة رقم ${attempt.attemptNumber}  •  ${DateTimeUtils.toShortDate(attempt.submittedAt)}  •  الوقت: $minutesUsed د $secondsUsed ث',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  if (attempt.incorrectCount > 0) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${attempt.correctCount} صحيحة  •  ${attempt.incorrectCount} خاطئة',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors.textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),

                                            // Score Badge
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: performanceColor.withAlpha(20),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    '${attempt.score} / ${widget.quiz.totalMarks > 0 ? widget.quiz.totalMarks : (attempt.score > 0 ? attempt.score : 1)}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                      color: performanceColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${performance.percentage.toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: performanceColor,
                                                  ),
                                                ),
                                                Text(
                                                  performance.labelArabic,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: performanceColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
              ),
            ],
          ),
        );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSel = widget.isSelected;
    final bg = isSel ? AppColors.primary : AppColors.surface;
    final bevel = isSel ? AppColors.primaryDark : AppColors.borderDark;
    final text = isSel ? Colors.white : AppColors.textSecondary;

    final pressOffset = _isPressed ? 2.5 : 0.0;
    const double bevelHeight = 3.0;
    const double height = 34.0;
    final double faceHeight = height - bevelHeight;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 3D Bevel Layer
            Positioned(
              top: bevelHeight,
              left: 0,
              right: 0,
              height: faceHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: bevel,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            // Tactile Face Layer (Non-positioned child gives Stack finite intrinsic width)
            AnimatedSlide(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOut,
              offset: Offset(0, _isPressed ? (pressOffset / faceHeight) : 0.0),
              child: Container(
                height: faceHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: isSel
                      ? null
                      : Border.all(color: AppColors.border, width: 1.2),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                    color: text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

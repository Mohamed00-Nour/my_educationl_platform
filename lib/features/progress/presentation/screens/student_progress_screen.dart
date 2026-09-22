import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/performance_rating.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/repositories/progress_repository.dart';
import '../bloc/student_progress_cubit.dart';

class StudentProgressScreen extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String courseId;

  const StudentProgressScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StudentProgressCubit(getIt<ProgressRepository>()),
      child: _StudentProgressView(
        studentId: studentId,
        studentName: studentName,
        courseId: courseId,
      ),
    );
  }
}

class _StudentProgressView extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String courseId;

  const _StudentProgressView({
    required this.studentId,
    required this.studentName,
    required this.courseId,
  });

  @override
  State<_StudentProgressView> createState() => _StudentProgressViewState();
}

class _StudentProgressViewState extends State<_StudentProgressView> {
  String _selectedPeriod = 'هذا الشهر'; // Default period

  @override
  void initState() {
    super.initState();
    _loadData(forceRefresh: true);
  }

  Future<void> _loadData({bool forceRefresh = false}) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    if (_selectedPeriod == 'هذا الأسبوع') {
      start = now.subtract(const Duration(days: 7));
      end = now;
    } else if (_selectedPeriod == 'هذا الشهر') {
      start = now.subtract(const Duration(days: 30));
      end = now;
    } else {
      // 'الكل (تراكمي)'
      start = null;
      end = null;
    }

    return context.read<StudentProgressCubit>().loadSummary(
          studentId: widget.studentId,
          studentName: widget.studentName,
          courseId: widget.courseId,
          startDate: start,
          endDate: end,
          forceRefresh: forceRefresh,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مستواي الأكاديمي'),
        actions: [
          BlocBuilder<StudentProgressCubit, StudentProgressState>(
            builder: (context, state) => IconButton(
              tooltip: 'تحديث البيانات',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: state is StudentProgressLoading
                  ? null
                  : () => _loadData(forceRefresh: true),
            ),
          ),
        ],
      ),
      body: BlocBuilder<StudentProgressCubit, StudentProgressState>(
        builder: (context, state) {
          if (state is StudentProgressLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is StudentProgressError) {
            return ErrorView(
              message: state.message,
              onRetry: () => _loadData(forceRefresh: true),
            );
          }

          if (state is StudentProgressLoaded) {
            final s = state.summary;
            final performance = PerformanceRating.fromPercentage(
              s.finalCompositeScore,
            );
            final performanceColor = AppColors.forPerformance(
              performance.band,
            );

            final trophyTitle = _selectedPeriod == 'هذا الشهر'
                ? 'تقييم هذا الشهر'
                : (_selectedPeriod == 'هذا الأسبوع'
                    ? 'تقييم هذا الأسبوع'
                    : 'التقييم التراكمي العام');

            final trophySubtitle = _selectedPeriod == 'هذا الشهر'
                ? 'بناءً على نشاط هذا الشهر (آخر 30 يوماً)'
                : (_selectedPeriod == 'هذا الأسبوع'
                    ? 'بناءً على نشاط هذا الأسبوع (آخر 7 أيام)'
                    : 'المعدل التراكمي الإجمالي لكامل الكورس');

            return RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              child: ResponsiveContent(
                maxWidth: 960,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: context.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Period Selector Strip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'الفترة:',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  'هذا الشهر',
                                  'هذا الأسبوع',
                                  'الكل (تراكمي)',
                                ].map((period) {
                                  final isSelected = _selectedPeriod == period;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6.0),
                                    child: ChoiceChip(
                                      label: Text(period),
                                      selected: isSelected,
                                      selectedColor: AppColors.primary,
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF131F24)
                                            : AppColors.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.border,
                                          width: isSelected ? 1.8 : 1.0,
                                        ),
                                      ),
                                      onSelected: (val) {
                                        if (val && _selectedPeriod != period) {
                                          setState(() => _selectedPeriod = period);
                                          _loadData(forceRefresh: true);
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Overall Evaluation Composite Trophy Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.primaryDark,
                            offset: Offset(0, 4.5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(30),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.warning,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              size: 36,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            trophyTitle,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trophySubtitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const Text(
                            'يُحسب التقييم من الأقسام المنجزة فقط، وتُعاد موازنة أوزانها',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${s.finalCompositeScore}%',
                            style: TextStyle(
                              color: performanceColor,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: performanceColor.withAlpha(80),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              s.totalSessions == 0 &&
                                      s.completedQuizzesCount == 0 &&
                                      s.completedExamsCount == 0
                                  ? (_selectedPeriod == 'الكل (تراكمي)'
                                      ? 'لا توجد بيانات تقييم بعد'
                                      : 'لا توجد نشاطات مسجلة خلال هذه الفترة')
                                  : performance.labelArabic,
                              style: TextStyle(
                                color: performanceColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'تفاصيل الأداء والدرجات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Attendance Metric Card
                    _ProgressComponentCard(
                      icon: Icons.calendar_today_rounded,
                      iconColor: AppColors.primary,
                      title: 'نسبة الحضور والالتزام (20%)',
                      value: s.totalSessions == 0
                          ? '—'
                          : '${s.attendancePercentage}%',
                      subtitle: s.totalSessions == 0
                          ? (_selectedPeriod == 'الكل (تراكمي)'
                              ? 'لا توجد جلسات حضور مسجلة حتى الآن؛ لا تدخل في التقييم'
                              : 'لا توجد جلسات حضور مسجلة خلال هذه الفترة؛ لا تدخل في التقييم')
                          : 'حضور: ${s.presentSessions} • غياب: ${s.absentSessions} • تأخير: ${s.lateSessions} (الإجمالي: ${s.totalSessions})',
                      progressValue: s.attendancePercentage / 100.0,
                      progressColor: AppColors.primary,
                    ),
                    const SizedBox(height: 12),

                    // Quiz Performance Card
                    _ProgressComponentCard(
                      icon: Icons.quiz_rounded,
                      iconColor: AppColors.secondary,
                      title: 'متوسط الاختبارات القصيرة (35%)',
                      value: s.completedQuizzesCount == 0
                          ? '—'
                          : '${s.quizAveragePercentage}%',
                      subtitle: s.completedQuizzesCount == 0
                          ? 'لم يُنجز أي اختبار قصير بعد؛ لا يدخل في التقييم'
                          : 'تم إنجاز ${s.completedQuizzesCount} اختبار قصير',
                      progressValue: s.quizAveragePercentage / 100.0,
                      progressColor: AppColors.secondary,
                    ),
                    const SizedBox(height: 12),

                    // Major Exam Card
                    _ProgressComponentCard(
                      icon: Icons.assignment_rounded,
                      iconColor: AppColors.accent,
                      title: 'الامتحانات الشاملة (45%)',
                      value: s.completedExamsCount == 0
                          ? '—'
                          : '${s.examAveragePercentage}%',
                      subtitle: s.completedExamsCount == 0
                          ? 'لم يُنجز أي امتحان شامل بعد؛ لا يدخل في التقييم'
                          : 'تم إنجاز ${s.completedExamsCount} امتحان شامل',
                      progressValue: s.examAveragePercentage / 100.0,
                      progressColor: AppColors.accent,
                    ),
                    const SizedBox(height: 12),

                    // Bonus / Minus Points Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.borderDark,
                            offset: Offset(0, 3.5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: AppColors.warning,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'نقاط السلوك والمشاركة والتطبيق',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+${s.totalBonusPoints} بونص  •  -${s.totalMinusPoints} خصم',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${s.netAdjustmentPoints >= 0 ? '+' : ''}${s.netAdjustmentPoints} نقطة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: s.netAdjustmentPoints >= 0
                                  ? AppColors.bonus
                                  : AppColors.minus,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ProgressComponentCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final double progressValue;
  final Color progressColor;

  const _ProgressComponentCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progressValue,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.borderDark,
            offset: Offset(0, 3.5),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconColor, width: 1.5),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: LinearProgressIndicator(
                value: progressValue.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

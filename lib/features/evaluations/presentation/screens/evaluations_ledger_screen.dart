import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/repositories/evaluation_repository.dart';
import '../bloc/evaluation_bloc.dart';
import '../widgets/add_adjustment_dialog.dart';

class EvaluationsLedgerScreen extends StatelessWidget {
  final String courseId;
  final String studentId;
  final String studentName;
  final bool isAdmin;
  final String teacherName;

  const EvaluationsLedgerScreen({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.studentName,
    required this.isAdmin,
    this.teacherName = 'المعلم',
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => EvaluationBloc(getIt<EvaluationRepository>())..add(
            LoadEvaluationsEvent(courseId: courseId, studentId: studentId),
          ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isAdmin
                ? 'سجل تقييم الطالب: $studentName'
                : 'سجل المكافآت والدرجات',
          ),
          actions: [
            if (isAdmin)
              Builder(
                builder:
                    (ctx) => IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'إضافة تقييم',
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder:
                              (_) => AddAdjustmentDialog(
                                courseId: courseId,
                                studentId: studentId,
                                studentName: studentName,
                                teacherName: teacherName,
                                onSaved: (adj) {
                                  ctx.read<EvaluationBloc>().add(
                                    AddAdjustmentEvent(adj),
                                  );
                                },
                              ),
                        );
                      },
                    ),
              ),
          ],
        ),
        body: BlocBuilder<EvaluationBloc, EvaluationState>(
          builder: (context, state) {
            if (state is EvaluationLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is EvaluationLoadedState) {
              return ResponsiveContent(
                maxWidth: 900,
                child: Column(
                  children: [
                  // Balance Summary Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        bottom: BorderSide(color: AppColors.border, width: 2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _BalanceItem(
                          label: 'نقاط المكافأة',
                          value: '+${state.totalBonusPoints}',
                          color: AppColors.bonus,
                        ),
                        _BalanceItem(
                          label: 'نقاط الخصم',
                          value: '-${state.totalMinusPoints}',
                          color: AppColors.minus,
                        ),
                        _BalanceItem(
                          label: 'صافي التقييم',
                          value:
                              '${state.netAdjustmentPoints >= 0 ? '+' : ''}${state.netAdjustmentPoints}',
                          color:
                              state.netAdjustmentPoints >= 0
                                  ? AppColors.bonus
                                  : AppColors.minus,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Ledger Items List
                  Expanded(
                    child:
                        state.adjustments.isEmpty
                            ? const EmptyStateView(
                              icon: Icons.star_border,
                              title: 'لا توجد تقييمات مسجلة',
                              message:
                                  'سيتم عرض تفاصيل المكافآت والخصومات فور إضافتها من المعلم.',
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: state.adjustments.length,
                              itemBuilder: (context, index) {
                                final adj = state.adjustments[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color:
                                                adj.isBonus
                                                    ? AppColors.successLight
                                                    : AppColors.errorLight,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            adj.isBonus
                                                ? Icons.add
                                                : Icons.remove,
                                            color:
                                                adj.isBonus
                                                    ? AppColors.bonus
                                                    : AppColors.minus,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    '${adj.isBonus ? '+' : ''}${adj.points} نقطة',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          adj.isBonus
                                                              ? AppColors.bonus
                                                              : AppColors.minus,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    DateTimeUtils.toDisplayDate(
                                                      adj.date,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                adj.reason,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              if (adj.teacherNotes != null &&
                                                  adj
                                                      .teacherNotes!
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'ملاحظة: ${adj.teacherNotes!}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (isAdmin)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: AppColors.textMuted,
                                            ),
                                            onPressed: () {
                                              context
                                                  .read<EvaluationBloc>()
                                                  .add(
                                                    DeleteAdjustmentEvent(
                                                      adj.id,
                                                    ),
                                                  );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BalanceItem({
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
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

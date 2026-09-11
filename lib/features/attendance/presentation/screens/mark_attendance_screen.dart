import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../bloc/attendance_bloc.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final String courseId;
  const MarkAttendanceScreen({super.key, required this.courseId});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final dateStr = DateTimeUtils.toDateString(_selectedDate);

    return BlocProvider(
      create:
          (context) => AttendanceBloc(getIt<AttendanceRepository>())..add(
            LoadSessionAttendanceEvent(
              courseId: widget.courseId,
              sessionDate: dateStr,
            ),
          ),
      child: Scaffold(
        appBar: AppBar(title: const Text('تسجيل الحضور والغياب')),
        body: BlocConsumer<AttendanceBloc, AttendanceState>(
          listener: (context, state) {
            if (state is AttendanceSaveSuccessState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم حفظ كشف الحضور لـ ${state.count} طالب بنجاح!',
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pop(context);
            }
          },
          builder: (context, state) {
            return ResponsiveContent(
              maxWidth: 880,
              child: Column(
              children: [
                // Date Picker Strip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateTimeUtils.toDisplayDate(_selectedDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_calendar, size: 16),
                        label: const Text('تغيير التاريخ'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(120, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                            if (context.mounted) {
                              context.read<AttendanceBloc>().add(
                                LoadSessionAttendanceEvent(
                                  courseId: widget.courseId,
                                  sessionDate: DateTimeUtils.toDateString(
                                    picked,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Quick Actions Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      if (state is AttendanceLoadedState) ...[
                        Text(
                          '${state.records.length} طالب',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('تحديد الكل حاضر'),
                        onPressed: () {
                          context.read<AttendanceBloc>().add(
                            MarkAllPresentEvent(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Students Attendance List
                Expanded(
                  child:
                      state is AttendanceLoading
                          ? const Center(child: CircularProgressIndicator())
                          : state is AttendanceLoadedState
                          ? ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: state.records.length,
                            itemBuilder: (context, index) {
                              final r = state.records[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primaryLight
                                            .withAlpha(25),
                                        child: Text(
                                          r.studentName.isNotEmpty
                                              ? r.studentName[0]
                                              : 'ط',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          r.studentName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),

                                      // 3-way toggle (Present / Late / Absent)
                                      _StatusChoice(
                                        currentStatus: r.status,
                                        onSelected: (newStatus) {
                                          context.read<AttendanceBloc>().add(
                                            ToggleStudentStatusEvent(
                                              studentId: r.studentId,
                                              newStatus: newStatus,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                          : const EmptyStateView(
                            icon: Icons.people_outline,
                            title: 'لا يوجد طلاب',
                            message:
                                'لم يتم العثور على طلاب مسجلين لتسجيل الحضور لهم.',
                          ),
                ),

                // Save Bottom Button
                if (state is AttendanceLoadedState && state.records.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        top: BorderSide(color: AppColors.border, width: 2),
                      ),
                    ),
                    child: AppButton(
                      label: 'حفظ جلسة الحضور',
                      icon: Icons.check,
                      isLoading: state.isSaving,
                      onPressed: () {
                        context.read<AttendanceBloc>().add(
                          SaveAttendanceSessionEvent(),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}

class _StatusChoice extends StatelessWidget {
  final AttendanceStatus currentStatus;
  final ValueChanged<AttendanceStatus> onSelected;

  const _StatusChoice({required this.currentStatus, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPill(
          label: 'حاضر',
          status: AttendanceStatus.present,
          activeBg: AppColors.successLight,
          activeText: AppColors.present,
          tooltip: 'حاضر',
        ),
        const SizedBox(width: 6),
        _buildPill(
          label: 'متأخر',
          status: AttendanceStatus.late,
          activeBg: AppColors.warningLight,
          activeText: AppColors.late,
          tooltip: 'متأخر',
        ),
        const SizedBox(width: 6),
        _buildPill(
          label: 'غائب',
          status: AttendanceStatus.absent,
          activeBg: AppColors.errorLight,
          activeText: AppColors.absent,
          tooltip: 'غائب',
        ),
      ],
    );
  }

  Widget _buildPill({
    required String label,
    required AttendanceStatus status,
    required Color activeBg,
    required Color activeText,
    required String tooltip,
  }) {
    final isSelected = currentStatus == status;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onSelected(status),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeBg : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeText : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? activeText : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

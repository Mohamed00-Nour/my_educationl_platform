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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            if (state is AttendanceLoadedState && state.savedCount != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم حفظ حضور ${state.savedCount} طالب بنجاح!',
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            } else if (state is AttendanceLoadedState &&
                state.saveError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.saveError!),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          builder: (context, state) {
            final visibleRecords =
                state is AttendanceLoadedState
                    ? state.records
                        .where(
                          (record) => record.studentName
                              .toLowerCase()
                              .contains(_searchQuery.trim().toLowerCase()),
                        )
                        .toList()
                    : const <AttendanceRecord>[];
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
                          '${state.records.length} طالب • ${state.changedStudentIds.length} محدد للحفظ',
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
                        onPressed: state is AttendanceLoadedState && !state.isSaving
                            ? () {
                          context.read<AttendanceBloc>().add(
                            MarkAllPresentEvent(),
                          );
                        }
                            : null,
                      ),
                    ],
                  ),
                ),

                if (state is AttendanceLoadedState)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن طالب بالاسم',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                if (state is AttendanceLoadedState)
                  const SizedBox(height: 12),

                // Students Attendance List
                Expanded(
                  child:
                      state is AttendanceLoading
                          ? const Center(child: CircularProgressIndicator())
                          : state is AttendanceLoadedState
                          ? visibleRecords.isEmpty
                              ? const Center(
                                child: Text('لا يوجد طالب يطابق البحث'),
                              )
                              : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: visibleRecords.length,
                            itemBuilder: (context, index) {
                              final r = visibleRecords[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
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
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (!state.savedStudentIds.contains(r.studentId) &&
                                          !state.changedStudentIds.contains(r.studentId))
                                        const Text(
                                          'لم تُسجّل حالته بعد',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      Align(
                                        alignment: AlignmentDirectional.centerEnd,
                                        child: _StatusChoice(
                                          currentStatus:
                                              state.savedStudentIds.contains(r.studentId) ||
                                                      state.changedStudentIds.contains(r.studentId)
                                                  ? r.status
                                                  : null,
                                          isEnabled: !state.isSaving,
                                          onSelected: (newStatus) {
                                            context.read<AttendanceBloc>().add(
                                              ToggleStudentStatusEvent(
                                                studentId: r.studentId,
                                                newStatus: newStatus,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      if (state.changedStudentIds.contains(r.studentId)) ...[
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: AlignmentDirectional.centerEnd,
                                          child: TextButton.icon(
                                            icon: const Icon(Icons.save_outlined),
                                            label: const Text('حفظ هذا الطالب'),
                                            onPressed: state.isSaving
                                                ? null
                                                : () => context.read<AttendanceBloc>().add(
                                                    SaveStudentAttendanceEvent(r.studentId),
                                                  ),
                                          ),
                                        ),
                                      ],
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
                      label: 'حفظ المحددين (${state.changedStudentIds.length})',
                      icon: Icons.check,
                      isLoading: state.isSaving,
                      onPressed: state.isSaving || state.changedStudentIds.isEmpty
                          ? null
                          : () {
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
  final AttendanceStatus? currentStatus;
  final bool isEnabled;
  final ValueChanged<AttendanceStatus> onSelected;

  const _StatusChoice({
    required this.currentStatus,
    required this.onSelected,
    this.isEnabled = true,
  });

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
        onTap: isEnabled ? () => onSelected(status) : null,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/admin_overview_entity.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/cubit/admin_management_cubit.dart';

class SuperAdminManagementScreen extends StatelessWidget {
  final UserEntity superAdmin;

  const SuperAdminManagementScreen({super.key, required this.superAdmin});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminManagementCubit>(
      create: (_) => getIt<AdminManagementCubit>()..loadSuperAdminOverview(),
      child: _SuperAdminView(superAdmin: superAdmin),
    );
  }
}

class _SuperAdminView extends StatelessWidget {
  final UserEntity superAdmin;

  const _SuperAdminView({required this.superAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('لوحة الإدارة العليا (Super Admin)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
            onPressed:
                () =>
                    context
                        .read<AdminManagementCubit>()
                        .loadSuperAdminOverview(),
          ),
        ],
      ),
      body: BlocConsumer<AdminManagementCubit, AdminManagementState>(
        listener: (context, state) {
          if (state is SuperAdminOverviewLoaded &&
              state.actionSuccessMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionSuccessMessage!),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is AdminManagementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminManagementLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SuperAdminOverviewLoaded) {
            final admins = state.admins;
            final totalStudents = admins.fold<int>(
              0,
              (sum, a) => sum + a.studentCount,
            );

            return RefreshIndicator(
              onRefresh:
                  () =>
                      context
                          .read<AdminManagementCubit>()
                          .loadSuperAdminOverview(),
              child: ResponsiveContent(
                maxWidth: 1000,
                child: ListView(
                  padding: context.screenPadding,
                  children: [
                    // Global Overview Cards
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'إجمالي المعلمين',
                            value: '${admins.length}',
                            icon: Icons.assignment_ind_outlined,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            title: 'إجمالي الطلاب المسجلين',
                            value: '$totalStudents',
                            icon: Icons.people_outline,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'قائمة المعلمين والمشرفين وأكواد الانضمام',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (admins.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'لا يوجد معلمون مسجلون في النظام حتى الآن.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...admins.map(
                        (admin) => _AdminCard(
                          admin: admin,
                          allAdmins: admins,
                          superAdminId: superAdmin.id,
                        ),
                      ),
                  ],
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.borderDark,
            offset: Offset(0, 3.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
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

class _AdminCard extends StatelessWidget {
  final AdminOverviewEntity admin;
  final List<AdminOverviewEntity> allAdmins;
  final String superAdminId;

  const _AdminCard({
    required this.admin,
    required this.allAdmins,
    required this.superAdminId,
  });

  @override
  Widget build(BuildContext context) {
    final code = admin.activeJoinCode;
    final hasActiveCode = code != null && code.isActive && !code.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasActiveCode ? AppColors.border : AppColors.errorLight,
          width: 1.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.borderDark,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Identity Row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.secondary.withAlpha(25),
                  child: Text(
                    admin.displayName.isNotEmpty
                        ? admin.displayName[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        admin.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        admin.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${admin.studentCount} طالب',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: AppColors.border),

            // Join Code Details
            if (code != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'كود الانضمام: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                hasActiveCode
                                    ? AppColors.primary
                                    : AppColors.error,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          code.code,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color:
                                hasActiveCode
                                    ? AppColors.primary
                                    : AppColors.error,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'نسخ الكود',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ كود الانضمام'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _StatusBadge(code: code),
                ],
              ),
              if (code.expiresAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'ينتهي في: ${DateTimeUtils.toShortDate(code.expiresAt!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        code.isExpired
                            ? AppColors.error
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ] else ...[
              const Text(
                'لا يوجد كود انضمام مسجل لهذا المعلم.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Actions Strip
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Regenerate Code
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text(
                    'تجديد الكود',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _confirmRegenerate(context),
                ),
                // Toggle Active / Inactive
                if (code != null)
                  OutlinedButton.icon(
                    icon: Icon(
                      code.isActive ? Icons.block : Icons.check_circle_outline,
                      size: 16,
                      color:
                          code.isActive ? AppColors.error : AppColors.primary,
                    ),
                    label: Text(
                      code.isActive ? 'تعطيل الكود' : 'تفعيل الكود',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            code.isActive ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    onPressed: () {
                      context.read<AdminManagementCubit>().superAdminToggleCode(
                        codeHash: code.codeHash,
                        isActive: !code.isActive,
                      );
                    },
                  ),
                // Manage Expiry
                if (code != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text(
                      code.expiresAt != null
                          ? 'تعديل الانتهاء'
                          : 'تحديد انتهاء',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _pickExpiry(context, code.codeHash),
                  ),
                // View & Transfer Students
                ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text(
                    'إدارة ونقل الطلاب',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _openStudentsModal(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRegenerate(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تأكيد تجديد كود المعلم'),
            content: Text(
              'سيتم إبطال كود المعلم الحالي وإنشاء كود جديد مكون من 6 أرقام.\n\nملاحظة هامة: لن يتأثر الطلاب المسجلون مسبقاً بهذا التغيير.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<AdminManagementCubit>().superAdminRegenerateCode(
                    targetAdminId: admin.adminId,
                    targetAdminName: admin.displayName,
                    superAdminId: superAdminId,
                  );
                },
                child: const Text('تأكيد التجديد'),
              ),
            ],
          ),
    );
  }

  void _pickExpiry(BuildContext context, String codeHash) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null && context.mounted) {
      context.read<AdminManagementCubit>().superAdminUpdateExpiry(
        codeHash: codeHash,
        expiresAt: picked,
      );
    }
  }

  void _openStudentsModal(BuildContext context) {
    final cubit = context.read<AdminManagementCubit>();
    cubit.loadStudentsForAdmin(admin.adminId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => BlocProvider.value(
            value: cubit,
            child: _StudentsTransferSheet(
              sourceAdmin: admin,
              allAdmins: allAdmins,
            ),
          ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final dynamic code;
  const _StatusBadge({required this.code});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (!code.isActive) {
      label = 'معطّل';
      color = AppColors.error;
    } else if (code.isExpired) {
      label = 'منتهي الصلاحية';
      color = AppColors.warning;
    } else {
      label = 'مفعّل ونشط';
      color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StudentsTransferSheet extends StatelessWidget {
  final AdminOverviewEntity sourceAdmin;
  final List<AdminOverviewEntity> allAdmins;

  const _StudentsTransferSheet({
    required this.sourceAdmin,
    required this.allAdmins,
  });

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return BlocBuilder<AdminManagementCubit, AdminManagementState>(
      builder: (context, state) {
        List<UserEntity>? students;
        if (state is SuperAdminOverviewLoaded) {
          students = state.adminStudents[sourceAdmin.adminId];
        }

        return SizedBox(
          width: double.infinity,
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'طلاب المعلم: ${sourceAdmin.displayName}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'اختر طالباً لنقله إلى معلم آخر بدون المساس بالسجلات السابقة',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 16),

                if (students == null)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (students.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'لا يوجد طلاب مسجلون لدى هذا المعلم.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final student = students![idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    AppColors.primaryLight.withAlpha(30),
                                child: Text(
                                  student.displayName.isNotEmpty
                                      ? student.displayName[0].toUpperCase()
                                      : 'ط',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${student.email} • ${student.grade?.toArabicDisplay() ?? "بدون مرحلة"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 34,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.swap_horiz, size: 14),
                                  label: const Text(
                                    'نقل',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(68, 34),
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed:
                                      () =>
                                          _showTransferDialog(context, student),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTransferDialog(BuildContext context, UserEntity student) {
    final candidateAdmins =
        allAdmins.where((a) => a.adminId != sourceAdmin.adminId).toList();

    if (candidateAdmins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد معلمون آخرون في النظام لإتمام عملية النقل.'),
        ),
      );
      return;
    }

    String selectedTargetAdminId = candidateAdmins.first.adminId;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('نقل الطالب إلى معلم آخر'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أنت على وشك نقل الطالب "${student.displayName}" من المعلم "${sourceAdmin.displayName}" إلى:',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedTargetAdminId,
                        decoration: const InputDecoration(
                          labelText: 'المعلم الجديد',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            candidateAdmins.map((a) {
                              return DropdownMenuItem<String>(
                                value: a.adminId,
                                child: Text('${a.displayName} (${a.email})'),
                              );
                            }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedTargetAdminId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ملاحظة: السجلات التاريخية للطالب من درجات واختبارات وحضور تظل محفوظة بالكامل دون أي تعديل.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context); // Close sheet
                        context.read<AdminManagementCubit>().transferStudent(
                          studentId: student.id,
                          newAdminId: selectedTargetAdminId,
                        );
                      },
                      child: const Text('تأكيد النقل'),
                    ),
                  ],
                ),
          ),
    );
  }
}

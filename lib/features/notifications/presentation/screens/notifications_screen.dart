import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/services/notification_queue_service.dart';

class NotificationsScreen extends StatefulWidget {
  final UserEntity user;
  final String? courseId;

  const NotificationsScreen({super.key, required this.user, this.courseId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  void _showCreateAnnouncementDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String targetType = 'all';

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: const Text('إرسال إعلان / تنبيه للطلاب'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppTextField(
                          controller: titleCtrl,
                          label: 'عنوان الإعلان',
                          hintText: 'مثال: تذكير بموعد الامتحان البرمجي',
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: bodyCtrl,
                          label: 'نص وتفاصيل الإعلان',
                          hintText: 'اكتب رسالتك وتوجيهاتك للطلاب هنا...',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: targetType,
                          decoration: const InputDecoration(
                            labelText: 'الفئة المستهدفة',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('جميع الطلاب (عام)'),
                            ),
                            DropdownMenuItem(
                              value: StudentGrade.firstSecondary.toValue(),
                              child: const Text('طلاب أولى ثانوي فقط'),
                            ),
                            DropdownMenuItem(
                              value: StudentGrade.secondSecondary.toValue(),
                              child: const Text('طلاب تانية ثانوي فقط'),
                            ),
                            if (widget.courseId != null)
                              const DropdownMenuItem(
                                value: 'course',
                                child: Text('طلاب هذا الكورس فقط'),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => targetType = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final body = bodyCtrl.text.trim();
                        if (title.isNotEmpty && body.isNotEmpty) {
                          final navigator = Navigator.of(ctx);
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          final queueService =
                              getIt<NotificationQueueService>();
                          await queueService.enqueueNotification(
                            targetType: targetType,
                            targetId: widget.courseId,
                            title: title,
                            body: body,
                          );

                          navigator.pop();
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم نشر الإعلان وإرسال الإشعار للطلاب بنجاح!',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      child: const Text('إرسال التنبيه'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditAnnouncementDialog({
    required String docId,
    required String initialTitle,
    required String initialBody,
    required String initialTargetType,
    String? initialTargetId,
  }) {
    final titleCtrl = TextEditingController(text: initialTitle);
    final bodyCtrl = TextEditingController(text: initialBody);
    String targetType = initialTargetType;
    bool isSaving = false;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('تعديل الإعلان / التنبيه'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppTextField(
                          controller: titleCtrl,
                          label: 'عنوان الإعلان',
                          hintText: 'مثال: تذكير بموعد الامتحان البرمجي',
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: bodyCtrl,
                          label: 'نص وتفاصيل الإعلان',
                          hintText: 'اكتب رسالتك وتوجيهاتك للطلاب هنا...',
                          maxLines: 4,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: targetType,
                          decoration: const InputDecoration(
                            labelText: 'الفئة المستهدفة',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('جميع الطلاب (عام)'),
                            ),
                            DropdownMenuItem(
                              value: StudentGrade.firstSecondary.toValue(),
                              child: const Text('طلاب أولى ثانوي فقط'),
                            ),
                            DropdownMenuItem(
                              value: StudentGrade.secondSecondary.toValue(),
                              child: const Text('طلاب تانية ثانوي فقط'),
                            ),
                            if (widget.courseId != null || initialTargetId != null)
                              const DropdownMenuItem(
                                value: 'course',
                                child: Text('طلاب هذا الكورس فقط'),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => targetType = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              final body = bodyCtrl.text.trim();
                              if (title.isEmpty || body.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('يرجى ملء جميع الحقول المطلوبة'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isSaving = true);
                              try {
                                final queueService =
                                    getIt<NotificationQueueService>();
                                await queueService.updateNotification(
                                  docId: docId,
                                  title: title,
                                  body: body,
                                  targetType: targetType,
                                  targetId: initialTargetId ?? widget.courseId,
                                );

                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تحديث الإعلان بنجاح!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('فشل تحديث الإعلان: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('حفظ التعديلات'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _confirmDeleteNotification(String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإعلان؟'),
        content: Text('هل أنت متأكد من حذف الإعلان "$title" نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final queueService = getIt<NotificationQueueService>();
                await queueService.deleteNotification(docId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الإعلان بنجاح.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل حذف الإعلان: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعلانات والتنبيهات'),
        actions: [
          if (widget.user.isAdmin)
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'إعلان جديد',
              onPressed: _showCreateAnnouncementDialog,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection(FirestoreCollections.notificationsQueue)
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final filtered =
              docs.where((d) {
                if (widget.user.isAdmin) return true;
                final data = d.data() as Map<String, dynamic>;
                final targetType = data['targetType'] as String? ?? 'all';
                final targetId = data['targetId'] as String?;
                if (targetType == 'all') return true;
                if (targetType == StudentGrade.firstSecondary.toValue()) {
                  return widget.user.grade == StudentGrade.firstSecondary;
                }
                if (targetType == StudentGrade.secondSecondary.toValue()) {
                  return widget.user.grade == StudentGrade.secondSecondary;
                }
                if (targetType == 'course') {
                  if (targetId == null ||
                      targetId == widget.courseId ||
                      widget.user.enrolledCourseIds.contains(targetId)) {
                    return true;
                  }
                }
                if (targetType == 'student' && targetId == widget.user.id)
                  return true;
                return false;
              }).toList();

          if (filtered.isEmpty) {
            return const EmptyStateView(
              icon: Icons.notifications_off_outlined,
              title: 'لا توجد تنبيهات حالياً',
              message:
                  'ستظهر هنا الإعلانات المدرسية وتذكيرات الامتحانات فور نشرها من المعلم.',
            );
          }

          return ResponsiveContent(
            maxWidth: 880,
            child: ListView.builder(
              padding: context.screenPadding,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
              final doc = filtered[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? 'إعلان';
              final body = data['body'] as String? ?? '';
              final targetType = data['targetType'] as String? ?? 'all';
              final timestamp = data['createdAt'];
              final hasBeenEdited = data['updatedAt'] != null;

              String timeStr = 'مؤخراً';
              if (timestamp is Timestamp) {
                timeStr = DateTimeUtils.toShortDate(timestamp.toDate());
              }

              IconData icon = Icons.campaign_outlined;
              Color iconColor = AppColors.secondary;

              final lowerTitle = title.toLowerCase();
              if (lowerTitle.contains('exam') ||
                  lowerTitle.contains('quiz') ||
                  lowerTitle.contains('امتحان') ||
                  lowerTitle.contains('اختبار')) {
                icon = Icons.assignment_outlined;
                iconColor = AppColors.primary;
              } else if (lowerTitle.contains('مذكرة') ||
                  lowerTitle.contains('ملف') ||
                  lowerTitle.contains('درس') ||
                  lowerTitle.contains('slide')) {
                icon = Icons.attach_file;
                iconColor = AppColors.info;
              } else if (lowerTitle.contains('bonus') ||
                  lowerTitle.contains('بونص') ||
                  lowerTitle.contains('مكافأة') ||
                  lowerTitle.contains('نقاط')) {
                icon = Icons.star_outline;
                iconColor = AppColors.bonus;
              }

              String targetLabel = 'عام - جميع الطلاب';
              if (targetType == StudentGrade.firstSecondary.toValue()) {
                targetLabel = 'أولى ثانوي';
              } else if (targetType == StudentGrade.secondSecondary.toValue()) {
                targetLabel = 'تانية ثانوي';
              } else if (targetType == 'course') {
                targetLabel = 'مجموعة الكورس';
              } else if (targetType == 'student') {
                targetLabel = 'إشعار خاص';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                if (hasBeenEdited) ...[
                                  const SizedBox(width: 4),
                                  const Text(
                                    '(معدّل)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              body,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    targetLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (widget.user.isAdmin) ...[
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 19,
                                      color: AppColors.primary,
                                    ),
                                    tooltip: 'تعديل الإعلان',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    onPressed: () => _showEditAnnouncementDialog(
                                      docId: doc.id,
                                      initialTitle: title,
                                      initialBody: body,
                                      initialTargetType: targetType,
                                      initialTargetId: data['targetId'] as String?,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 19,
                                      color: AppColors.error,
                                    ),
                                    tooltip: 'حذف الإعلان',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    onPressed: () => _confirmDeleteNotification(
                                      doc.id,
                                      title,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
        },
      ),
    );
  }
}

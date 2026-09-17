import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/course_notification_request.dart';

class PushNotificationDraft {
  bool enabled;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final TextEditingController payloadController;

  PushNotificationDraft({
    this.enabled = false,
    required String defaultTitle,
    required String defaultBody,
  }) : titleController = TextEditingController(text: defaultTitle),
       bodyController = TextEditingController(text: defaultBody),
       payloadController = TextEditingController();

  String? validate() {
    if (!enabled) return null;
    if (titleController.text.trim().isEmpty) return 'يرجى كتابة عنوان الإشعار.';
    if (bodyController.text.trim().isEmpty) return 'يرجى كتابة نص الإشعار.';

    final rawPayload = payloadController.text.trim();
    if (rawPayload.isEmpty) return null;
    if (utf8.encode(rawPayload).length > 3000) {
      return 'بيانات الإشعار الإضافية كبيرة جداً (الحد 3000 بايت).';
    }
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map<String, dynamic>) {
        return 'بيانات الإشعار الإضافية يجب أن تكون JSON Object.';
      }
      const reservedKeys = {
        'from',
        'message_type',
        'courseId',
        'contentType',
        'contentId',
      };
      final hasReservedKey = decoded.keys.any(
        (key) =>
            reservedKeys.contains(key) ||
            key.startsWith('google.') ||
            key.startsWith('gcm.'),
      );
      if (hasReservedKey) {
        return 'بيانات JSON تحتوي على مفتاح محجوز للتطبيق.';
      }
    } catch (_) {
      return 'صيغة JSON في بيانات الإشعار غير صحيحة.';
    }
    return null;
  }

  CourseNotificationRequest? buildRequest({
    required String courseId,
    required String contentType,
    String? contentId,
    String? lessonId,
  }) {
    if (!enabled) return null;
    final payload = <String, String>{};

    final rawPayload = payloadController.text.trim();
    if (rawPayload.isNotEmpty) {
      final decoded = jsonDecode(rawPayload) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        payload[entry.key] = entry.value.toString();
      }
    }
    payload['courseId'] = courseId;
    payload['contentType'] = contentType;
    if (contentId != null && contentId.isNotEmpty) {
      payload['contentId'] = contentId;
    }
    if (lessonId != null && lessonId.isNotEmpty) {
      payload['lessonId'] = lessonId;
    }

    return CourseNotificationRequest(
      courseId: courseId,
      title: titleController.text.trim(),
      body: bodyController.text.trim(),
      dataPayload: payload,
    );
  }

  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    payloadController.dispose();
  }
}

class PushNotificationFields extends StatefulWidget {
  final PushNotificationDraft draft;

  const PushNotificationFields({super.key, required this.draft});

  @override
  State<PushNotificationFields> createState() => _PushNotificationFieldsState();
}

class _PushNotificationFieldsState extends State<PushNotificationFields> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'إرسال إشعار للطلاب؟',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'سيصل فقط إلى الطلاب المسجلين في هذا الكورس',
              style: TextStyle(fontSize: 11),
            ),
            value: widget.draft.enabled,
            onChanged: (value) {
              setState(() => widget.draft.enabled = value);
            },
          ),
          if (widget.draft.enabled) ...[
            const SizedBox(height: 8),
            TextField(
              controller: widget.draft.titleController,
              decoration: const InputDecoration(labelText: 'عنوان الإشعار *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.draft.bodyController,
              decoration: const InputDecoration(labelText: 'نص الإشعار *'),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.draft.payloadController,
              decoration: const InputDecoration(
                labelText: 'بيانات إضافية (JSON اختياري)',
                hintText: '{"screen":"lesson"}',
                helperText: 'courseId وcontentType يضافان تلقائياً',
              ),
              keyboardType: TextInputType.multiline,
              maxLines: 3,
              textDirection: TextDirection.ltr,
            ),
          ],
        ],
      ),
    );
  }
}

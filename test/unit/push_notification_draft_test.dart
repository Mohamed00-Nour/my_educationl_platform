import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/notifications/presentation/widgets/push_notification_fields.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationDraft', () {
    test('disabled notification produces no request', () {
      final draft = PushNotificationDraft(
        defaultTitle: 'عنوان',
        defaultBody: 'رسالة',
      );

      expect(draft.validate(), isNull);
      expect(
        draft.buildRequest(courseId: 'course-1', contentType: 'lesson'),
        isNull,
      );
      draft.dispose();
    });

    test('builds string-only payload with protected routing fields', () {
      final draft = PushNotificationDraft(
        enabled: true,
        defaultTitle: 'درس جديد',
        defaultBody: 'تمت إضافة درس جديد',
      );
      draft.payloadController.text = '{"screen":"lesson","page":2}';

      expect(draft.validate(), isNull);
      final request = draft.buildRequest(
        courseId: 'course-1',
        contentType: 'lesson',
        contentId: 'lesson-2',
        lessonId: 'lesson-2',
      );

      expect(request!.courseId, 'course-1');
      expect(request.dataPayload['screen'], 'lesson');
      expect(request.dataPayload['page'], '2');
      expect(request.dataPayload['courseId'], 'course-1');
      expect(request.dataPayload['contentId'], 'lesson-2');
      expect(request.dataPayload['lessonId'], 'lesson-2');
      draft.dispose();
    });

    test('rejects invalid JSON and reserved routing keys', () {
      final draft = PushNotificationDraft(
        enabled: true,
        defaultTitle: 'عنوان',
        defaultBody: 'رسالة',
      );

      draft.payloadController.text = 'not-json';
      expect(draft.validate(), isNotNull);

      draft.payloadController.text = '{"courseId":"another-course"}';
      expect(draft.validate(), contains('محجوز'));
      draft.dispose();
    });
  });
}

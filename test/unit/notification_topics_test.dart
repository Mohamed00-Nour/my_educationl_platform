import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/notifications/domain/services/notification_topics.dart';

void main() {
  group('NotificationTopics', () {
    test('builds isolated teacher and course topics', () {
      expect(NotificationTopics.course('course_123'), 'course_course_123');
      expect(
        NotificationTopics.teacherStudents('teacher_123'),
        'teacher_teacher_123_students',
      );
    });

    test('sanitizes course ids for Firebase topic requirements', () {
      expect(NotificationTopics.course(' course/id 1 '), 'course_course_id_1');
    });
  });
}

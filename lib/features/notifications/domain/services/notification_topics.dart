abstract final class NotificationTopics {
  static String course(String courseId) => 'course_${_safeSegment(courseId)}';

  static String teacherStudents(String teacherId) =>
      'teacher_${_safeSegment(teacherId)}_students';

  static String _safeSegment(String value) {
    final normalized = value.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9\-_.~%]'),
      '_',
    );
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value', 'FCM topic segment is empty');
    }
    return normalized;
  }
}

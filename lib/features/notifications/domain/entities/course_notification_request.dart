class CourseNotificationRequest {
  final String courseId;
  final String title;
  final String body;
  final Map<String, String> dataPayload;

  const CourseNotificationRequest({
    required this.courseId,
    required this.title,
    required this.body,
    this.dataPayload = const {},
  });

  CourseNotificationRequest withPayload(Map<String, String> values) {
    return CourseNotificationRequest(
      courseId: courseId,
      title: title,
      body: body,
      dataPayload: {...dataPayload, ...values},
    );
  }
}

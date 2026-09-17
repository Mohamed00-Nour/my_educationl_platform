import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/course_notification_request.dart';
import '../../domain/services/notification_topics.dart';
import 'embedded_fcm_sender.dart';

class NotificationQueueService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final EmbeddedFcmSender _sender;

  NotificationQueueService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    EmbeddedFcmSender? sender,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _sender = sender ?? EmbeddedFcmSender();

  Future<bool> enqueueCourseNotification(CourseNotificationRequest request) {
    return enqueueNotification(
      targetType: 'course',
      targetId: request.courseId,
      title: request.title,
      body: request.body,
      dataPayload: request.dataPayload,
    );
  }

  Future<bool> enqueueNotification({
    required String targetType, // 'teacher', 'course', 'student'
    String? targetId,
    required String title,
    required String body,
    Map<String, dynamic>? dataPayload,
  }) async {
    // Treat the former global "all" option as "all of this teacher's
    // students" so an older caller can never broadcast across tenants.
    final effectiveTargetType = targetType == 'all' ? 'teacher' : targetType;
    final effectiveTargetId =
        effectiveTargetType == 'teacher' ? _auth.currentUser?.uid : targetId;
    var status = 'sent';
    String? deliveryError;
    final payload = <String, dynamic>{
      ...?dataPayload,
      'targetType': effectiveTargetType,
      if (effectiveTargetId != null) 'targetId': effectiveTargetId,
    };

    try {
      await _deliver(
        targetType: effectiveTargetType,
        targetId: effectiveTargetId,
        title: title,
        body: body,
        dataPayload: payload,
      );
    } catch (error) {
      status = 'failed';
      deliveryError = error.toString();
    }

    try {
      await _firestore.collection(FirestoreCollections.notificationsQueue).add({
        'targetType': effectiveTargetType,
        'targetId': effectiveTargetId,
        'title': title,
        'body': body,
        'dataPayload': payload,
        'status': status,
        'deliveryMode': 'embedded_fcm_http_v1',
        'createdBy': _auth.currentUser?.uid,
        if (deliveryError != null) 'error': deliveryError,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Notification history is non-blocking; delivery may already have worked.
    }
    return status == 'sent';
  }

  Future<void> _deliver({
    required String targetType,
    required String? targetId,
    required String title,
    required String body,
    required Map<String, dynamic> dataPayload,
  }) async {
    if (targetType == 'course') {
      if (targetId == null || targetId.trim().isEmpty) {
        throw const FcmSendException(
          'A course notification requires a course ID.',
        );
      }
      await _assertCanTargetCourse(targetId);
      return _sender.sendToTopic(
        topic: NotificationTopics.course(targetId),
        title: title,
        body: body,
        data: dataPayload,
      );
    }

    if (targetType == 'teacher') {
      if (targetId == null || targetId.trim().isEmpty) {
        throw const FcmSendException(
          'A teacher notification requires an authenticated teacher ID.',
        );
      }
      return _sender.sendToTopic(
        topic: NotificationTopics.teacherStudents(targetId),
        title: title,
        body: body,
        data: dataPayload,
      );
    }

    if (targetType == 'student' && targetId != null) {
      final student =
          await _firestore
              .collection(FirestoreCollections.users)
              .doc(targetId)
              .get();
      final tokens = List<String>.from(
        student.data()?['fcmTokens'] as List<dynamic>? ?? const [],
      ).where((token) => token.trim().isNotEmpty);
      if (tokens.isEmpty) {
        throw const FcmSendException(
          'The selected student has no registered notification device.',
        );
      }
      await Future.wait(
        tokens.map(
          (token) => _sender.sendToToken(
            token: token,
            title: title,
            body: body,
            data: dataPayload,
          ),
        ),
      );
      return;
    }

    throw FcmSendException('Unsupported notification target: $targetType');
  }

  Future<void> _assertCanTargetCourse(String courseId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw const FcmSendException(
        'An authenticated teacher is required to send notifications.',
      );
    }

    final results = await Future.wait([
      _firestore.collection(FirestoreCollections.users).doc(userId).get(),
      _firestore.collection(FirestoreCollections.courses).doc(courseId).get(),
    ]);
    final userData = results[0].data();
    final courseData = results[1].data();
    if (userData?['role'] == AppConstants.roleSuperAdmin) return;
    if (courseData == null || courseData['ownerAdminId'] != userId) {
      throw const FcmSendException(
        'A teacher can only notify students in a course they own.',
      );
    }
  }

  Future<void> updateNotification({
    required String docId,
    required String title,
    required String body,
    required String targetType,
    String? targetId,
  }) async {
    try {
      final effectiveTargetType = targetType == 'all' ? 'teacher' : targetType;
      final effectiveTargetId =
          effectiveTargetType == 'teacher' ? _auth.currentUser?.uid : targetId;
      await _firestore
          .collection(FirestoreCollections.notificationsQueue)
          .doc(docId)
          .update({
            'title': title,
            'body': body,
            'targetType': effectiveTargetType,
            'targetId': effectiveTargetId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      rethrow;
    }
  }

  Future<void> deleteNotification(String docId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.notificationsQueue)
          .doc(docId)
          .delete();
    } catch (_) {
      rethrow;
    }
  }
}

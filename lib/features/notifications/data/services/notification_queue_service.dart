import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';

class NotificationQueueService {
  final FirebaseFirestore _firestore;

  NotificationQueueService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> enqueueNotification({
    required String targetType, // 'all', 'course', 'student'
    String? targetId,
    required String title,
    required String body,
    Map<String, dynamic>? dataPayload,
  }) async {
    try {
      await _firestore.collection(FirestoreCollections.notificationsQueue).add({
        'targetType': targetType,
        'targetId': targetId,
        'title': title,
        'body': body,
        'dataPayload': dataPayload ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-blocking queue failure
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
      await _firestore
          .collection(FirestoreCollections.notificationsQueue)
          .doc(docId)
          .update({
            'title': title,
            'body': body,
            'targetType': targetType,
            'targetId': targetId,
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


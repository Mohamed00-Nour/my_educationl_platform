import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';

class FCMService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  FCMService({FirebaseMessaging? messaging, FirebaseFirestore? firestore})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> initializeForUser(String userId) async {
    try {
      // 1. Request permissions (especially required on iOS, macOS, Web)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 2. Fetch FCM Token
        final token = await _messaging.getToken();
        if (token != null) {
          await _saveTokenToFirestore(userId, token);
        }

        // 3. Listen to token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          _saveTokenToFirestore(userId, newToken);
        });

        // 4. Default topic subscription
        await subscribeToTopic('all_students');
      }
    } catch (e) {
      debugPrint('FCM initialization error: $e');
    }
  }

  Future<void> subscribeToCourse(String courseId) async {
    try {
      await _messaging.subscribeToTopic('course_$courseId');
    } catch (_) {}
  }

  Future<void> unsubscribeFromCourse(String courseId) async {
    try {
      await _messaging.unsubscribeFromTopic('course_$courseId');
    } catch (_) {}
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (_) {}
  }

  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .update({
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastActive': FieldValue.serverTimestamp(),
          });
    } catch (_) {}
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/services/notification_topics.dart';

class FCMService {
  static const String _managedTopicsKey = 'fcm_managed_topics';
  static const AndroidNotificationChannel _courseUpdatesChannel =
      AndroidNotificationChannel(
        'course_updates',
        'تحديثات الكورسات',
        description: 'إشعارات الدروس والملحقات والاختبارات الجديدة',
        importance: Importance.high,
      );

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final SharedPreferences _preferences;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _activeUserId;
  bool _receiverInitialized = false;

  FCMService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    required SharedPreferences preferences,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _preferences = preferences,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  /// Makes this device's managed topics exactly match the authenticated
  /// student's current course enrollment.
  Future<void> initializeForUser(UserEntity user) async {
    try {
      await _initializeReceiver();

      if (_activeUserId != null && _activeUserId != user.id) {
        await clearForSignedOutUser();
      }
      _activeUserId = user.id;

      if (!user.isStudent) {
        await _syncManagedTopics(const <String>{});
        return;
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!isAuthorized) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(user.id, token);
      }

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        final activeUserId = _activeUserId;
        if (activeUserId != null) {
          _saveTokenToFirestore(activeUserId, newToken);
        }
      });

      final desiredTopics = <String>{
        ...user.enrolledCourseIds.map(NotificationTopics.course),
        if (user.ownerAdminId != null && user.ownerAdminId!.trim().isNotEmpty)
          NotificationTopics.teacherStudents(user.ownerAdminId!),
      };
      await _syncManagedTopics(desiredTopics);
    } catch (error, stackTrace) {
      debugPrint('FCM initialization error: $error\n$stackTrace');
    }
  }

  /// Removes locally managed subscriptions and this device token when the
  /// account signs out or another account is opened on the same device.
  Future<void> clearForSignedOutUser() async {
    final userId = _activeUserId;
    try {
      final token = await _messaging.getToken();
      if (userId != null && token != null) {
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .update({
              'fcmTokens': FieldValue.arrayRemove([token]),
            });
      }
    } catch (error) {
      debugPrint('Could not remove the signed-out FCM token: $error');
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    await _syncManagedTopics(const <String>{});
    _activeUserId = null;
  }

  Future<void> _syncManagedTopics(Set<String> desiredTopics) async {
    final previousTopics =
        _preferences.getStringList(_managedTopicsKey)?.toSet() ?? <String>{};
    final synchronizedTopics = Set<String>.from(previousTopics);

    for (final topic in previousTopics.difference(desiredTopics)) {
      try {
        await _messaging.unsubscribeFromTopic(topic);
        synchronizedTopics.remove(topic);
      } catch (error) {
        debugPrint('Could not unsubscribe from $topic: $error');
      }
    }
    for (final topic in desiredTopics.difference(previousTopics)) {
      try {
        await _messaging.subscribeToTopic(topic);
        synchronizedTopics.add(topic);
      } catch (error) {
        debugPrint('Could not subscribe to $topic: $error');
      }
    }

    await _preferences.setStringList(
      _managedTopicsKey,
      synchronizedTopics.toList()..sort(),
    );
  }

  Future<void> _initializeReceiver() async {
    if (_receiverInitialized) return;
    _receiverInitialized = true;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initializationSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_courseUpdatesChannel);

    // Apple platforms can display FCM notifications while in foreground.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    // Avoid duplicating the native foreground notification on Apple platforms.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }

    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'course_updates',
          'تحديثات الكورسات',
          channelDescription: 'إشعارات الدروس والملحقات والاختبارات الجديدة',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
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
    } catch (error) {
      debugPrint('Could not save the FCM token: $error');
    }
  }
}

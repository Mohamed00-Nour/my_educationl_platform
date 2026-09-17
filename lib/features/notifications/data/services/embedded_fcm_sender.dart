import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';

/// Temporary FCM HTTP v1 sender used while the project has no trusted backend.
///
/// SECURITY: the service-account private key is bundled with the application
/// and can be extracted from a distributed build. Keep this implementation
/// isolated and replace it with a trusted HTTPS endpoint before production.
class EmbeddedFcmSender {
  static const String credentialsAsset =
      'assets/secrets/firebase-service-account.json';
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  Future<_SenderSession>? _session;

  Future<void> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    final normalizedTopic = _normalizeTopic(topic);
    await _send(
      target: {'topic': normalizedTopic},
      title: title,
      body: body,
      data: data,
    );
  }

  Future<void> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    if (token.trim().isEmpty) {
      throw const FcmSendException('The target FCM token is empty.');
    }
    await _send(
      target: {'token': token.trim()},
      title: title,
      body: body,
      data: data,
    );
  }

  Future<void> _send({
    required Map<String, String> target,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final session = await (_session ??= _createSession());
    final endpoint = Uri.https(
      'fcm.googleapis.com',
      '/v1/projects/${session.projectId}/messages:send',
    );
    final response = await session.client.post(
      endpoint,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'message': {
          ...target,
          'notification': {'title': title.trim(), 'body': body.trim()},
          'data': _stringData(data),
          'android': {
            'priority': 'high',
            'notification': {'channel_id': 'course_updates'},
          },
          'apns': {
            'payload': {
              'aps': {'sound': 'default'},
            },
          },
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FcmSendException(
        'FCM rejected the notification (${response.statusCode}): '
        '${response.body}',
      );
    }
  }

  Future<_SenderSession> _createSession() async {
    late final String rawCredentials;
    try {
      rawCredentials = await rootBundle.loadString(credentialsAsset);
    } catch (_) {
      throw const FcmSendException(
        'Firebase service-account credentials are missing. Add the JSON file '
        'to assets/secrets/firebase-service-account.json.',
      );
    }

    final decoded = jsonDecode(rawCredentials);
    if (decoded is! Map<String, dynamic>) {
      throw const FcmSendException(
        'The Firebase service-account JSON has an invalid format.',
      );
    }
    final projectId = decoded['project_id']?.toString().trim() ?? '';
    if (projectId.isEmpty) {
      throw const FcmSendException(
        'The Firebase service-account JSON does not contain project_id.',
      );
    }

    final credentials = ServiceAccountCredentials.fromJson(decoded);
    final client = await clientViaServiceAccount(credentials, _scopes);
    return _SenderSession(projectId: projectId, client: client);
  }

  static Map<String, String> _stringData(Map<String, dynamic> data) {
    return data.map((key, value) {
      final stringValue =
          value is String
              ? value
              : (value is num || value is bool || value == null)
              ? value.toString()
              : jsonEncode(value);
      return MapEntry(key, stringValue);
    });
  }

  static String _normalizeTopic(String topic) {
    final normalized = topic.trim().replaceFirst(RegExp(r'^/topics/'), '');
    if (normalized.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9\-_.~%]+$').hasMatch(normalized)) {
      throw FcmSendException('Invalid FCM topic: $topic');
    }
    return normalized;
  }
}

class _SenderSession {
  final String projectId;
  final AutoRefreshingAuthClient client;

  const _SenderSession({required this.projectId, required this.client});
}

class FcmSendException implements Exception {
  final String message;

  const FcmSendException(this.message);

  @override
  String toString() => message;
}

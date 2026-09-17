import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class RemoteHtmlLoader {
  static const int defaultMaxBytes = 20 * 1024 * 1024;

  final int maxBytes;
  final Duration timeout;

  const RemoteHtmlLoader({
    this.maxBytes = defaultMaxBytes,
    this.timeout = const Duration(seconds: 45),
  });

  Future<String> load(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const RemoteHtmlException('رابط ملف HTML غير صالح.');
    }

    final client = http.Client();
    try {
      final request = http.Request(
        'GET',
        uri,
      )..headers['accept'] = 'text/html,application/xhtml+xml,text/plain;q=0.9';
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RemoteHtmlException(
          'تعذر تنزيل ملف HTML (رمز ${response.statusCode}). '
          'تأكد أن صلاحية Google Drive هي «أي شخص لديه الرابط».',
        );
      }

      final declaredLength = response.contentLength;
      if (declaredLength != null && declaredLength > maxBytes) {
        throw const RemoteHtmlException(
          'ملف HTML كبير جداً للعرض المباشر داخل التطبيق.',
        );
      }

      final bytes = BytesBuilder(copy: false);
      var receivedBytes = 0;
      await for (final chunk in response.stream.timeout(timeout)) {
        receivedBytes += chunk.length;
        if (receivedBytes > maxBytes) {
          throw const RemoteHtmlException(
            'ملف HTML كبير جداً للعرض المباشر داخل التطبيق.',
          );
        }
        bytes.add(chunk);
      }

      final html = utf8.decode(bytes.takeBytes(), allowMalformed: true);
      if (html.trim().isEmpty) {
        throw const RemoteHtmlException('ملف HTML فارغ.');
      }

      final lower = html.toLowerCase();
      if (lower.contains('accounts.google.com') ||
          lower.contains('servicelogin')) {
        throw const RemoteHtmlException(
          'لا يمكن تنزيل الملف. اجعل صلاحية Google Drive '
          '«أي شخص لديه الرابط» ثم أعد المحاولة.',
        );
      }
      return html;
    } on TimeoutException {
      throw const RemoteHtmlException(
        'انتهت مهلة تنزيل ملف HTML. تحقق من الاتصال وحاول مرة أخرى.',
      );
    } finally {
      client.close();
    }
  }
}

class RemoteHtmlException implements Exception {
  final String message;

  const RemoteHtmlException(this.message);

  @override
  String toString() => message;
}

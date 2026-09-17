import 'package:url_launcher/url_launcher.dart';

class UrlService {
  /// Normalizes a URL by ensuring it contains an appropriate scheme (e.g. https://).
  static String normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // Check if URL already has a known scheme
    final schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');
    if (schemePattern.hasMatch(trimmed) ||
        trimmed.startsWith('mailto:') ||
        trimmed.startsWith('tel:') ||
        trimmed.startsWith('sms:')) {
      return trimmed;
    }

    // Default to https://
    return 'https://$trimmed';
  }

  /// Returns whether [input] is a valid HTTP(S) URL that can be shared with
  /// other devices. Local file paths must never be stored as course material
  /// URLs because they only exist on the administrator's device.
  static bool isShareableWebUrl(String input) {
    final raw = input.trim();
    if (raw.isEmpty ||
        raw.contains(r'\') ||
        raw.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(raw)) {
      return false;
    }

    final normalized = normalizeUrl(raw);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return false;
    }

    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '0.0.0.0' ||
        host == '127.0.0.1' ||
        host == '::1') {
      return false;
    }

    return true;
  }

  /// Whether this is a Google Drive or Google Workspace file link.
  static bool isGoogleHostedFileUrl(String input) {
    final uri = Uri.tryParse(normalizeUrl(input));
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    if (host == 'drive.google.com' || host == 'www.drive.google.com') {
      return extractGoogleDriveFileId(input) != null;
    }

    if (host == 'docs.google.com') {
      final segments = uri.pathSegments;
      return segments.length >= 3 &&
          const {
            'document',
            'presentation',
            'spreadsheets',
          }.contains(segments.first.toLowerCase()) &&
          segments[1] == 'd' &&
          segments[2].isNotEmpty;
    }

    return false;
  }

  /// Extracts the file id from the common Google Drive sharing URL formats.
  static String? extractGoogleDriveFileId(String input) {
    final uri = Uri.tryParse(normalizeUrl(input));
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    if (host != 'drive.google.com' && host != 'www.drive.google.com') {
      return null;
    }

    final queryId = uri.queryParameters['id']?.trim();
    if (queryId != null && queryId.isNotEmpty) return queryId;

    final segments = uri.pathSegments;
    final dIndex = segments.indexOf('d');
    if (dIndex >= 0 && dIndex + 1 < segments.length) {
      final id = segments[dIndex + 1].trim();
      if (id.isNotEmpty) return id;
    }

    return null;
  }

  /// Returns a direct-download URL for a publicly shared Google Drive file.
  /// This is used for HTML materials because Drive's preview page displays
  /// HTML source code instead of executing the document.
  static String? googleDriveDownloadUrl(String input) {
    final fileId = extractGoogleDriveFileId(input);
    if (fileId == null) return null;

    return Uri.https('drive.usercontent.google.com', '/download', {
      'id': fileId,
      'export': 'download',
      'confirm': 't',
    }).toString();
  }

  /// Produces a URL intended for an in-app WebView. Google share pages are
  /// converted to their preview form so Drive streams the content instead of
  /// the app trying to download a potentially multi-gigabyte file.
  static String inAppViewerUrl(String input) {
    final normalized = normalizeUrl(input);
    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;

    final driveId = extractGoogleDriveFileId(normalized);
    if (driveId != null) {
      return Uri.https(
        'drive.google.com',
        '/file/d/$driveId/preview',
      ).toString();
    }

    if (uri.host.toLowerCase() == 'docs.google.com') {
      final segments = uri.pathSegments;
      if (segments.length >= 3 &&
          const {
            'document',
            'presentation',
            'spreadsheets',
          }.contains(segments.first.toLowerCase()) &&
          segments[1] == 'd' &&
          segments[2].isNotEmpty) {
        return Uri.https(
          'docs.google.com',
          '/${segments.first}/d/${segments[2]}/preview',
        ).toString();
      }
    }

    return normalized;
  }

  /// Opens an external URL with multi-tier fallback for maximum device compatibility.
  static Future<bool> openExternalUrl(String urlString) async {
    try {
      final normalized = normalizeUrl(urlString);
      if (normalized.isEmpty) return false;

      final uri = Uri.parse(normalized);

      // Attempt 1: External Application (Default browser / dedicated app)
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {
        // Fallback to next mode
      }

      // Attempt 2: Platform Default
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (launched) return true;
      } catch (_) {
        // Fallback to next mode
      }

      // Attempt 3: In-App Browser View
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
        if (launched) return true;
      } catch (_) {
        // All modes failed
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}

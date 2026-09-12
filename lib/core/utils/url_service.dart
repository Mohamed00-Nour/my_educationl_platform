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

  /// Opens an external URL with multi-tier fallback for maximum device compatibility.
  static Future<bool> openExternalUrl(String urlString) async {
    try {
      final normalized = normalizeUrl(urlString);
      if (normalized.isEmpty) return false;

      final uri = Uri.parse(normalized);

      // Attempt 1: External Application (Default browser / dedicated app)
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
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

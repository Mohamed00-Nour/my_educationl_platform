import 'package:url_launcher/url_launcher.dart';

class UrlService {
  static Future<bool> openExternalUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString.trim());
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

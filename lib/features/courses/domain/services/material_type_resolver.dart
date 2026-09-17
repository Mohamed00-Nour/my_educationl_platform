import '../entities/lesson_material_entity.dart';

/// Detects how a material should be opened from its actual source.
///
/// The admin-selected type is intentionally not used here. It remains useful
/// as a display hint when an opaque sharing URL does not expose a file name.
class MaterialTypeResolver {
  static const _videoExtensions = {'mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi'};

  static const _slideExtensions = {'ppt', 'pptx', 'odp', 'key'};

  static CourseMaterialType? detect(String source, {String? fileName}) {
    final normalized = source.trim().toLowerCase();
    if (normalized.contains('youtube.com') || normalized.contains('youtu.be')) {
      return CourseMaterialType.video;
    }

    final uri = Uri.tryParse(source.trim());
    if (uri != null && uri.host.toLowerCase() == 'docs.google.com') {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty && segments.first == 'presentation') {
        return CourseMaterialType.slides;
      }
    }

    final extension = _extensionOf(fileName ?? _fileNameFromSource(source));
    if (extension == 'pdf') return CourseMaterialType.pdf;
    if (_videoExtensions.contains(extension)) return CourseMaterialType.video;
    if (extension == 'html' || extension == 'htm') {
      return CourseMaterialType.interactiveHtml;
    }
    if (_slideExtensions.contains(extension)) return CourseMaterialType.slides;

    return null;
  }

  static CourseMaterialType typeForStorage(
    String source, {
    String? fileName,
    required CourseMaterialType hint,
  }) {
    return detect(source, fileName: fileName) ?? hint;
  }

  static String _fileNameFromSource(String source) {
    final uri = Uri.tryParse(source.trim());
    if (uri == null || uri.pathSegments.isEmpty) return source;

    // Some cloud/CDN URLs keep the object path in one encoded segment.
    return Uri.decodeComponent(uri.pathSegments.last);
  }

  static String _extensionOf(String value) {
    final clean = value.split('?').first.split('#').first;
    final dot = clean.lastIndexOf('.');
    if (dot < 0 || dot == clean.length - 1) return '';
    return clean.substring(dot + 1).toLowerCase();
  }
}

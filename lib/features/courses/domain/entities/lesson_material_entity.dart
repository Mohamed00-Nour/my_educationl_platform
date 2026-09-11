import 'package:equatable/equatable.dart';

enum CourseMaterialType {
  ministryBook,
  slides,
  summaryPdf,
  video,
  link,
  pdf;

  static CourseMaterialType fromString(String? type) {
    if (type == null) return CourseMaterialType.link;
    final lower = type.toLowerCase().trim();
    if (lower == 'ministrybook' || lower == 'book') {
      return CourseMaterialType.ministryBook;
    }
    if (lower == 'slides' || lower == 'presentation') {
      return CourseMaterialType.slides;
    }
    if (lower == 'summarypdf' || lower == 'summary') {
      return CourseMaterialType.summaryPdf;
    }
    if (lower == 'video' || lower == 'youtube') {
      return CourseMaterialType.video;
    }
    if (lower == 'pdf') return CourseMaterialType.pdf;
    return CourseMaterialType.link;
  }

  String toValue() => name;

  String toArabicDisplay() {
    switch (this) {
      case CourseMaterialType.ministryBook:
        return 'كتاب الوزارة';
      case CourseMaterialType.slides:
        return 'عرض تقديمي (شرائح)';
      case CourseMaterialType.summaryPdf:
      case CourseMaterialType.pdf:
        return 'ملخص الدرس (PDF)';
      case CourseMaterialType.video:
        return 'فيديو شرح';
      case CourseMaterialType.link:
        return 'رابط إلكتروني';
    }
  }
}

class LessonMaterialEntity extends Equatable {
  final String id;
  final String title;
  final CourseMaterialType type;
  final String url;
  final String? notes;
  final int? startPage;
  final int? endPage;

  const LessonMaterialEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    this.notes,
    this.startPage,
    this.endPage,
  });

  @override
  List<Object?> get props => [id, title, type, url, notes, startPage, endPage];
}

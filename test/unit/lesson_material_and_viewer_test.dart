import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/utils/url_service.dart';
import 'package:instructor/features/courses/data/models/lesson_material_model.dart';
import 'package:instructor/features/courses/domain/entities/lesson_material_entity.dart';

void main() {
  group('CourseMaterialType & LessonMaterialEntity Tests', () {
    test('Every CourseMaterialType has a distinct Arabic display name (no duplicates)', () {
      final displays = CourseMaterialType.values.map((t) => t.toArabicDisplay()).toList();
      final uniqueDisplays = displays.toSet();

      // Ensure no duplicates exist in Arabic displays
      expect(
        uniqueDisplays.length,
        equals(displays.length),
        reason: 'Each material type must have a unique Arabic display label in the UI dropdown',
      );

      // Verify specific expected values
      expect(CourseMaterialType.summaryPdf.toArabicDisplay(), equals('ملخص الدرس (PDF)'));
      expect(CourseMaterialType.pdf.toArabicDisplay(), equals('مستند / ملف (PDF)'));
      expect(CourseMaterialType.ministryBook.toArabicDisplay(), equals('كتاب الوزارة'));
      expect(CourseMaterialType.interactiveHtml.toArabicDisplay(), equals('نشاط أو صفحة (HTML)'));
      expect(CourseMaterialType.video.toArabicDisplay(), equals('فيديو شرح'));
      expect(CourseMaterialType.link.toArabicDisplay(), equals('رابط إلكتروني'));
    });

    test('fromString accurately maps all variations including html, interactive, and pdf', () {
      expect(CourseMaterialType.fromString('html'), equals(CourseMaterialType.interactiveHtml));
      expect(CourseMaterialType.fromString('interactivehtml'), equals(CourseMaterialType.interactiveHtml));
      expect(CourseMaterialType.fromString('htm'), equals(CourseMaterialType.interactiveHtml));
      expect(CourseMaterialType.fromString('pdf'), equals(CourseMaterialType.pdf));
      expect(CourseMaterialType.fromString('summarypdf'), equals(CourseMaterialType.summaryPdf));
      expect(CourseMaterialType.fromString('summary'), equals(CourseMaterialType.summaryPdf));
      expect(CourseMaterialType.fromString('video'), equals(CourseMaterialType.video));
      expect(CourseMaterialType.fromString('book'), equals(CourseMaterialType.ministryBook));
      expect(CourseMaterialType.fromString(null), equals(CourseMaterialType.link));
      expect(CourseMaterialType.fromString('unknown_type'), equals(CourseMaterialType.link));
    });

    test('LessonMaterialModel correctly serializes and deserializes interactiveHtml', () {
      const entity = LessonMaterialEntity(
        id: 'mat_test_1',
        title: 'نشاط برمجة بايثون التفاعلي',
        type: CourseMaterialType.interactiveHtml,
        url: 'https://example.com/python_activity.html',
        notes: 'نشاط عملي تفاعلي',
        startPage: null,
        endPage: null,
      );

      final model = LessonMaterialModel.fromEntity(entity);
      final map = model.toMap();

      expect(map['type'], equals('interactiveHtml'));
      expect(map['title'], equals('نشاط برمجة بايثون التفاعلي'));

      final restored = LessonMaterialModel.fromMap(map);
      expect(restored.type, equals(CourseMaterialType.interactiveHtml));
      expect(restored.title, equals(entity.title));
      expect(restored.url, equals(entity.url));
    });
  });

  group('UrlService URL Normalization Tests', () {
    test('Prepends https:// to URLs missing scheme', () {
      expect(UrlService.normalizeUrl('google.com'), equals('https://google.com'));
      expect(UrlService.normalizeUrl('www.youtube.com/watch?v=123'), equals('https://www.youtube.com/watch?v=123'));
      expect(UrlService.normalizeUrl('subdomain.domain.org/path?q=1'), equals('https://subdomain.domain.org/path?q=1'));
    });

    test('Preserves existing valid schemes', () {
      expect(UrlService.normalizeUrl('https://google.com'), equals('https://google.com'));
      expect(UrlService.normalizeUrl('http://insecure.site.com'), equals('http://insecure.site.com'));
      expect(UrlService.normalizeUrl('file:///C:/test/file.pdf'), equals('file:///C:/test/file.pdf'));
      expect(UrlService.normalizeUrl('mailto:teacher@school.com'), equals('mailto:teacher@school.com'));
      expect(UrlService.normalizeUrl('tel:123456789'), equals('tel:123456789'));
    });

    test('Handles empty and whitespace-only strings gracefully', () {
      expect(UrlService.normalizeUrl(''), equals(''));
      expect(UrlService.normalizeUrl('   '), equals(''));
    });
  });
}

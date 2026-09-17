import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/utils/url_service.dart';
import 'package:instructor/features/courses/data/models/lesson_material_model.dart';
import 'package:instructor/features/courses/domain/entities/lesson_material_entity.dart';
import 'package:instructor/features/courses/domain/services/material_type_resolver.dart';

void main() {
  group('CourseMaterialType & LessonMaterialEntity Tests', () {
    test(
      'Every CourseMaterialType has a distinct Arabic display name (no duplicates)',
      () {
        final displays =
            CourseMaterialType.values.map((t) => t.toArabicDisplay()).toList();
        final uniqueDisplays = displays.toSet();

        // Ensure no duplicates exist in Arabic displays
        expect(
          uniqueDisplays.length,
          equals(displays.length),
          reason:
              'Each material type must have a unique Arabic display label in the UI dropdown',
        );

        // Verify specific expected values
        expect(
          CourseMaterialType.summaryPdf.toArabicDisplay(),
          equals('ملخص الدرس (PDF)'),
        );
        expect(
          CourseMaterialType.pdf.toArabicDisplay(),
          equals('مستند / ملف (PDF)'),
        );
        expect(
          CourseMaterialType.ministryBook.toArabicDisplay(),
          equals('كتاب الوزارة'),
        );
        expect(
          CourseMaterialType.interactiveHtml.toArabicDisplay(),
          equals('نشاط أو صفحة (HTML)'),
        );
        expect(CourseMaterialType.video.toArabicDisplay(), equals('فيديو شرح'));
        expect(
          CourseMaterialType.link.toArabicDisplay(),
          equals('رابط إلكتروني'),
        );
      },
    );

    test(
      'fromString accurately maps all variations including html, interactive, and pdf',
      () {
        expect(
          CourseMaterialType.fromString('html'),
          equals(CourseMaterialType.interactiveHtml),
        );
        expect(
          CourseMaterialType.fromString('interactivehtml'),
          equals(CourseMaterialType.interactiveHtml),
        );
        expect(
          CourseMaterialType.fromString('htm'),
          equals(CourseMaterialType.interactiveHtml),
        );
        expect(
          CourseMaterialType.fromString('pdf'),
          equals(CourseMaterialType.pdf),
        );
        expect(
          CourseMaterialType.fromString('summarypdf'),
          equals(CourseMaterialType.summaryPdf),
        );
        expect(
          CourseMaterialType.fromString('summary'),
          equals(CourseMaterialType.summaryPdf),
        );
        expect(
          CourseMaterialType.fromString('video'),
          equals(CourseMaterialType.video),
        );
        expect(
          CourseMaterialType.fromString('book'),
          equals(CourseMaterialType.ministryBook),
        );
        expect(
          CourseMaterialType.fromString(null),
          equals(CourseMaterialType.link),
        );
        expect(
          CourseMaterialType.fromString('unknown_type'),
          equals(CourseMaterialType.link),
        );
      },
    );

    test(
      'LessonMaterialModel correctly serializes and deserializes interactiveHtml',
      () {
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
      },
    );
  });

  group('UrlService URL Normalization Tests', () {
    test('Prepends https:// to URLs missing scheme', () {
      expect(
        UrlService.normalizeUrl('google.com'),
        equals('https://google.com'),
      );
      expect(
        UrlService.normalizeUrl('www.youtube.com/watch?v=123'),
        equals('https://www.youtube.com/watch?v=123'),
      );
      expect(
        UrlService.normalizeUrl('subdomain.domain.org/path?q=1'),
        equals('https://subdomain.domain.org/path?q=1'),
      );
    });

    test('Preserves existing valid schemes', () {
      expect(
        UrlService.normalizeUrl('https://google.com'),
        equals('https://google.com'),
      );
      expect(
        UrlService.normalizeUrl('http://insecure.site.com'),
        equals('http://insecure.site.com'),
      );
      expect(
        UrlService.normalizeUrl('file:///C:/test/file.pdf'),
        equals('file:///C:/test/file.pdf'),
      );
      expect(
        UrlService.normalizeUrl('mailto:teacher@school.com'),
        equals('mailto:teacher@school.com'),
      );
      expect(UrlService.normalizeUrl('tel:123456789'), equals('tel:123456789'));
    });

    test('Handles empty and whitespace-only strings gracefully', () {
      expect(UrlService.normalizeUrl(''), equals(''));
      expect(UrlService.normalizeUrl('   '), equals(''));
    });

    test('accepts remote share URLs and rejects local device paths', () {
      expect(
        UrlService.isShareableWebUrl(
          'https://drive.google.com/file/d/abc/view',
        ),
        isTrue,
      );
      expect(UrlService.isShareableWebUrl('example.com/file.pdf'), isTrue);
      expect(UrlService.isShareableWebUrl(r'C:\Downloads\lesson.pdf'), isFalse);
      expect(
        UrlService.isShareableWebUrl('/storage/emulated/0/lesson.pdf'),
        isFalse,
      );
      expect(
        UrlService.isShareableWebUrl('http://localhost:8080/file'),
        isFalse,
      );
    });

    test('converts Google Drive sharing URLs to streaming preview URLs', () {
      const shareUrl =
          'https://drive.google.com/file/d/1AbC_23-xYz/view?usp=sharing';

      expect(UrlService.isGoogleHostedFileUrl(shareUrl), isTrue);
      expect(
        UrlService.extractGoogleDriveFileId(shareUrl),
        equals('1AbC_23-xYz'),
      );
      expect(
        UrlService.inAppViewerUrl(shareUrl),
        equals('https://drive.google.com/file/d/1AbC_23-xYz/preview'),
      );
      expect(
        UrlService.googleDriveDownloadUrl(shareUrl),
        equals(
          'https://drive.usercontent.google.com/download?'
          'id=1AbC_23-xYz&export=download&confirm=t',
        ),
      );
    });

    test('supports Drive query links and Google Workspace previews', () {
      const driveQueryUrl = 'https://drive.google.com/open?id=file123';
      const slidesUrl =
          'https://docs.google.com/presentation/d/slides123/edit?usp=sharing';

      expect(
        UrlService.extractGoogleDriveFileId(driveQueryUrl),
        equals('file123'),
      );
      expect(
        UrlService.inAppViewerUrl(driveQueryUrl),
        equals('https://drive.google.com/file/d/file123/preview'),
      );
      expect(UrlService.isGoogleHostedFileUrl(slidesUrl), isTrue);
      expect(
        UrlService.inAppViewerUrl(slidesUrl),
        equals('https://docs.google.com/presentation/d/slides123/preview'),
      );
    });
  });

  group('MaterialTypeResolver', () {
    test('detects the actual type without using the admin hint', () {
      expect(
        MaterialTypeResolver.detect(
          'https://cdn.example.com/file.pdf?token=abc',
        ),
        CourseMaterialType.pdf,
      );
      expect(
        MaterialTypeResolver.detect('https://youtu.be/video-id'),
        CourseMaterialType.video,
      );
      expect(
        MaterialTypeResolver.detect('https://example.com/activity.HTML'),
        CourseMaterialType.interactiveHtml,
      );
    });

    test('detects cloud files from their encoded object path', () {
      const url =
          'https://cdn.example.com/files/'
          'course_materials%2Fadmin%2Fcourse%2Flesson%2Flesson_video.mp4?alt=media';

      expect(MaterialTypeResolver.detect(url), CourseMaterialType.video);
    });

    test('uses the selected classification only when the source is opaque', () {
      expect(
        MaterialTypeResolver.typeForStorage(
          'https://drive.google.com/file/d/opaque/view',
          hint: CourseMaterialType.summaryPdf,
        ),
        CourseMaterialType.summaryPdf,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/constants/app_constants.dart';
import 'package:instructor/features/courses/domain/services/course_json_parser.dart';

void main() {
  group('CourseJsonParser Tests', () {
    test('successfully parses valid course JSON with units and lessons', () {
      const validJson = '''
      {
        "course": {
          "title": "مقدمة في البرمجة",
          "description": "كورس تمهيدي",
          "academicYear": "2026-2027",
          "targetGrade": "firstSecondary",
          "units": [
            {
              "title": "الوحدة الأولى: المفاهيم الأساسية",
              "description": "مقدمة عامة",
              "orderIndex": 0,
              "lessons": [
                {
                  "title": "الدرس الأول: ما هي الخوارزميات؟",
                  "content": "شرح مفهوم الخوارزميات",
                  "orderIndex": 0,
                  "materials": [
                    {
                      "title": "كتاب الوزارة",
                      "type": "ministryBook",
                      "url": "https://example.com/book.pdf"
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
      ''';

      final result = CourseJsonParser.parseAndValidate(
        validJson,
        existingCourseTitles: ['كورس قديم'],
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.data, isNotNull);
      expect(result.data!.title, 'مقدمة في البرمجة');
      expect(result.data!.academicYear, '2026-2027');
      expect(result.data!.targetGrade, StudentGrade.firstSecondary);
      expect(result.totalUnits, 1);
      expect(result.totalLessons, 1);
      expect(result.data!.units.first.lessons.first.materials.length, 1);
    });

    test('successfully parses direct root JSON structure without course wrapper', () {
      const directJson = '''
      {
        "title": "الحاسب الآلي والذكاء الاصطناعي",
        "description": "مقرر الصف الثاني الثانوي",
        "academicYear": "2026-2027",
        "targetGrade": "secondSecondary",
        "units": [
          {
            "title": "الوحدة الأولى",
            "lessons": [
              {
                "title": "الدرس الأول"
              }
            ]
          }
        ]
      }
      ''';

      final result = CourseJsonParser.parseAndValidate(directJson);

      expect(result.isValid, isTrue);
      expect(result.data!.title, 'الحاسب الآلي والذكاء الاصطناعي');
      expect(result.data!.targetGrade, StudentGrade.secondSecondary);
      expect(result.totalUnits, 1);
      expect(result.totalLessons, 1);
    });

    test('rejects malformed non-JSON text', () {
      const invalidJson = 'This is not a JSON document';

      final result = CourseJsonParser.parseAndValidate(invalidJson);

      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('صيغة JSON غير صحيحة'));
      expect(result.data, isNull);
    });

    test('rejects JSON missing course title', () {
      const missingTitleJson = '''
      {
        "units": [
          {
            "title": "الوحدة الأولى",
            "lessons": [{"title": "الدرس الأول"}]
          }
        ]
      }
      ''';

      final result = CourseJsonParser.parseAndValidate(missingTitleJson);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('عنوان الكورس (title) مطلوب')), isTrue);
    });

    test('rejects JSON with no units', () {
      const noUnitsJson = '''
      {
        "title": "كورس فارغ",
        "units": []
      }
      ''';

      final result = CourseJsonParser.parseAndValidate(noUnitsJson);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('يجب أن يحتوي الكورس على وحدة دراسية واحدة على الأقل')), isTrue);
    });

    test('rejects unit missing title', () {
      const unitNoTitleJson = '''
      {
        "title": "كورس تجريبي",
        "units": [
          {
            "lessons": [{"title": "الدرس الأول"}]
          }
        ]
      }
      ''';

      final result = CourseJsonParser.parseAndValidate(unitNoTitleJson);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('تفتقد لعنوان')), isTrue);
    });

    test('rejects lesson missing title', () {
      const lessonNoTitleJson = '''
      {
        "title": "كورس تجريبي",
        "units": [
          {
            "title": "الوحدة الأولى",
            "lessons": [{"content": "محتوى بلا عنوان"}]
          }
        ]
      }
      ''';

      final result = CourseJsonParser.parseAndValidate(lessonNoTitleJson);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('يفتقد للعنوان')), isTrue);
    });

    test('warns when course title duplicates an existing course', () {
      const duplicateTitleJson = '''
      {
        "title": "كورس مكرر",
        "units": [
          {
            "title": "الوحدة 1",
            "lessons": [{"title": "الدرس 1"}]
          }
        ]
      }
      ''';

      final result = CourseJsonParser.parseAndValidate(
        duplicateTitleJson,
        existingCourseTitles: ['كورس مكرر'],
      );

      // Still valid, but contains a warning
      expect(result.isValid, isTrue);
      expect(result.warnings.any((w) => w.contains('يوجد لديك بالفعل كورس نشط')), isTrue);
    });

    test('ignores sensitive security fields in imported payload', () {
      const maliciousPayload = '''
      {
        "ownerAdminId": "hacker-admin-id",
        "uid": "hacker-user-id",
        "role": "superAdmin",
        "title": "كورس آمن",
        "units": [
          {
            "id": "injected-unit-id",
            "title": "الوحدة الأولى",
            "lessons": [
              {
                "id": "injected-lesson-id",
                "title": "الدرس الأول"
              }
            ]
          }
        ]
      }
      ''';

      final result = CourseJsonParser.parseAndValidate(maliciousPayload);

      expect(result.isValid, isTrue);
      expect(result.data!.title, 'كورس آمن');
      expect(result.totalUnits, 1);
      expect(result.totalLessons, 1);
    });
  });
}

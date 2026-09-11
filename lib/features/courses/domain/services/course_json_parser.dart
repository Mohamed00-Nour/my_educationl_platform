import 'dart:convert';
import '../../../../core/constants/app_constants.dart';
import '../entities/course_import_schema.dart';
import '../entities/lesson_material_entity.dart';

class CourseJsonParser {
  /// Parses and validates raw JSON text representing a course structure.
  /// Does NOT trust any sensitive or privileged fields from the input.
  static CourseImportValidationResult parseAndValidate(
    String rawJson, {
    List<String>? existingCourseTitles,
  }) {
    final List<String> errors = [];
    final List<String> warnings = [];

    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const CourseImportValidationResult(
        isValid: false,
        errors: ['الملف فارغ، يرجى اختيار ملف يحتوي على بيانات بصيغة JSON.'],
      );
    }

    dynamic decoded;
    try {
      decoded = json.decode(trimmed);
    } catch (e) {
      return CourseImportValidationResult(
        isValid: false,
        errors: ['صيغة JSON غير صحيحة أو تالفة: $e'],
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const CourseImportValidationResult(
        isValid: false,
        errors: ['محتوى JSON غير صالح، يجب أن يكون كائناً (Object/Map).'],
      );
    }

    // Support both {"course": { ... }} and direct {"title": "...", "units": [...]}
    final Map<String, dynamic> courseMap;
    if (decoded.containsKey('course') && decoded['course'] is Map<String, dynamic>) {
      courseMap = decoded['course'] as Map<String, dynamic>;
    } else {
      courseMap = decoded;
    }

    // 1. Validate Course Title (Strict required)
    final rawTitle = courseMap['title'];
    if (rawTitle == null || rawTitle is! String || rawTitle.trim().isEmpty) {
      errors.add('عنوان الكورس (title) مطلوب ولا يمكن أن يكون فارغاً.');
    }
    final courseTitle = rawTitle is String ? rawTitle.trim() : '';

    // Course optional fields
    final description = (courseMap['description'] as String?)?.trim() ?? '';
    final academicYear = (courseMap['academicYear'] as String?)?.trim() ?? '2025-2026';

    StudentGrade targetGrade = StudentGrade.firstSecondary;
    if (courseMap.containsKey('targetGrade')) {
      final gradeVal = courseMap['targetGrade'];
      if (gradeVal is String) {
        if (gradeVal.contains('second') || gradeVal.contains('تانية') || gradeVal.contains('ثاني')) {
          targetGrade = StudentGrade.secondSecondary;
        }
      }
    }

    // 2. Validate Units (Strict required)
    final rawUnits = courseMap['units'];
    if (rawUnits == null) {
      errors.add('حقل الوحدات (units) مفقود في ملف الكورس.');
    } else if (rawUnits is! List) {
      errors.add('حقل الوحدات (units) يجب أن يكون قائمة (List).');
    } else if (rawUnits.isEmpty) {
      errors.add('يجب أن يحتوي الكورس على وحدة دراسية واحدة على الأقل.');
    }

    final List<CourseImportUnitData> parsedUnits = [];
    int totalLessons = 0;
    int totalMaterials = 0;

    if (rawUnits is List) {
      for (int uIdx = 0; uIdx < rawUnits.length; uIdx++) {
        final rawUnit = rawUnits[uIdx];
        if (rawUnit is! Map<String, dynamic>) {
          errors.add('الوحدة رقم ${uIdx + 1} بتنسيق غير صالح، يجب أن تكون كائناً (Object).');
          continue;
        }

        // Validate unit title
        final unitTitle = (rawUnit['title'] as String?)?.trim();
        if (unitTitle == null || unitTitle.isEmpty) {
          errors.add('الوحدة رقم ${uIdx + 1} تفتقد لعنوان (title).');
        }

        final unitDesc = (rawUnit['description'] as String?)?.trim() ?? '';
        final unitOrder = (rawUnit['order'] as num?)?.toInt() ?? (uIdx + 1);
        final unitBookPage = (rawUnit['bookStartPage'] as num?)?.toInt();

        // Validate Lessons inside Unit
        final rawLessons = rawUnit['lessons'];
        final List<CourseImportLessonData> parsedLessons = [];

        if (rawLessons != null && rawLessons is! List) {
          errors.add('حقل الدروس (lessons) في الوحدة رقم ${uIdx + 1} يجب أن يكون قائمة.');
        } else if (rawLessons is List) {
          if (rawLessons.isEmpty) {
            warnings.add('الوحدة رقم ${uIdx + 1} (${unitTitle ?? "بدون عنوان"}) لا تحتوي على أي دروس.');
          }

          for (int lIdx = 0; lIdx < rawLessons.length; lIdx++) {
            final rawLesson = rawLessons[lIdx];
            if (rawLesson is! Map<String, dynamic>) {
              errors.add('الدرس رقم ${lIdx + 1} في الوحدة رقم ${uIdx + 1} بتنسيق غير صالح.');
              continue;
            }

            final lessonTitle = (rawLesson['title'] as String?)?.trim();
            if (lessonTitle == null || lessonTitle.isEmpty) {
              errors.add('الدرس رقم ${lIdx + 1} في الوحدة "${unitTitle ?? (uIdx + 1).toString()}" يفتقد للعنوان (title).');
            }

            final lessonDesc = (rawLesson['description'] as String?)?.trim() ?? '';
            final lessonOrder = (rawLesson['order'] as num?)?.toInt() ?? (lIdx + 1);
            final lessonBookPage = (rawLesson['bookStartPage'] as num?)?.toInt();
            final lessonNotes = (rawLesson['notes'] as String?)?.trim();

            // Validate materials
            final List<LessonMaterialEntity> parsedMaterials = [];
            final rawMaterials = rawLesson['materials'];
            if (rawMaterials is List) {
              for (int mIdx = 0; mIdx < rawMaterials.length; mIdx++) {
                final rawMat = rawMaterials[mIdx];
                if (rawMat is Map<String, dynamic>) {
                  final matTitle = (rawMat['title'] as String?)?.trim() ?? 'ملحق ${mIdx + 1}';
                  final matUrl = (rawMat['url'] as String?)?.trim() ?? '';
                  final matTypeStr = (rawMat['type'] as String?)?.trim().toLowerCase() ?? '';

                  CourseMaterialType matType = CourseMaterialType.link;
                  if (matTypeStr.contains('book') || matTypeStr.contains('وزارة')) {
                    matType = CourseMaterialType.ministryBook;
                  } else if (matTypeStr.contains('slide') || matTypeStr.contains('عرض')) {
                    matType = CourseMaterialType.slides;
                  } else if (matTypeStr.contains('summary') || matTypeStr.contains('ملخص')) {
                    matType = CourseMaterialType.summaryPdf;
                  } else if (matTypeStr.contains('video') || matTypeStr.contains('فيديو')) {
                    matType = CourseMaterialType.video;
                  } else if (matTypeStr.contains('pdf')) {
                    matType = CourseMaterialType.pdf;
                  }

                  parsedMaterials.add(
                    LessonMaterialEntity(
                      id: 'mat_${uIdx + 1}_${lIdx + 1}_${mIdx + 1}',
                      title: matTitle,
                      type: matType,
                      url: matUrl,
                      startPage: (rawMat['startPage'] as num?)?.toInt(),
                      endPage: (rawMat['endPage'] as num?)?.toInt(),
                      notes: (rawMat['notes'] as String?)?.trim(),
                    ),
                  );
                  totalMaterials++;
                }
              }
            }

            parsedLessons.add(
              CourseImportLessonData(
                title: lessonTitle ?? 'درس ${lIdx + 1}',
                description: lessonDesc,
                order: lessonOrder,
                bookStartPage: lessonBookPage,
                notes: lessonNotes,
                materials: parsedMaterials,
              ),
            );
            totalLessons++;
          }
        }

        parsedUnits.add(
          CourseImportUnitData(
            title: unitTitle ?? 'وحدة ${uIdx + 1}',
            description: unitDesc,
            order: unitOrder,
            bookStartPage: unitBookPage,
            lessons: parsedLessons,
          ),
        );
      }
    }

    // 3. Duplicate Course Check (Idempotency Warning)
    if (existingCourseTitles != null && courseTitle.isNotEmpty) {
      final normalizedNew = courseTitle.toLowerCase();
      final hasDuplicate = existingCourseTitles.any(
        (existing) => existing.trim().toLowerCase() == normalizedNew,
      );
      if (hasDuplicate) {
        warnings.add(
          'تنبيه: يوجد لديك بالفعل كورس نشط يحمل نفس الاسم ("$courseTitle"). يمكنك تعديل اسم الكورس في المعاينة أو المتابعة لإنشاء نسخة جديدة مستقلة.',
        );
      }
    }

    final isValid = errors.isEmpty;
    CourseImportData? importData;
    if (isValid) {
      importData = CourseImportData(
        title: courseTitle,
        description: description,
        academicYear: academicYear,
        targetGrade: targetGrade,
        units: parsedUnits,
      );
    }

    return CourseImportValidationResult(
      isValid: isValid,
      errors: errors,
      warnings: warnings,
      data: importData,
      totalUnits: parsedUnits.length,
      totalLessons: totalLessons,
      totalMaterials: totalMaterials,
    );
  }
}

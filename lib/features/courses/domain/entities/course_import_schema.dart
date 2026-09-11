import '../../../../core/constants/app_constants.dart';
import 'lesson_material_entity.dart';

class CourseImportLessonData {
  final String title;
  final String description;
  final int order;
  final int? bookStartPage;
  final String? notes;
  final List<LessonMaterialEntity> materials;

  const CourseImportLessonData({
    required this.title,
    this.description = '',
    this.order = 1,
    this.bookStartPage,
    this.notes,
    this.materials = const [],
  });
}

class CourseImportUnitData {
  final String title;
  final String description;
  final int order;
  final int? bookStartPage;
  final List<CourseImportLessonData> lessons;

  const CourseImportUnitData({
    required this.title,
    this.description = '',
    this.order = 1,
    this.bookStartPage,
    this.lessons = const [],
  });
}

class CourseImportData {
  final String title;
  final String description;
  final String academicYear;
  final StudentGrade targetGrade;
  final List<CourseImportUnitData> units;

  const CourseImportData({
    required this.title,
    this.description = '',
    this.academicYear = '2025-2026',
    this.targetGrade = StudentGrade.firstSecondary,
    required this.units,
  });

  CourseImportData copyWith({
    String? title,
    String? description,
    String? academicYear,
    StudentGrade? targetGrade,
    List<CourseImportUnitData>? units,
  }) {
    return CourseImportData(
      title: title ?? this.title,
      description: description ?? this.description,
      academicYear: academicYear ?? this.academicYear,
      targetGrade: targetGrade ?? this.targetGrade,
      units: units ?? this.units,
    );
  }
}

class CourseImportValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final CourseImportData? data;
  final int totalUnits;
  final int totalLessons;
  final int totalMaterials;

  const CourseImportValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.data,
    this.totalUnits = 0,
    this.totalLessons = 0,
    this.totalMaterials = 0,
  });
}

import '../../data/datasources/ministry_course_seeder.dart';
import '../entities/course_entity.dart';
import '../entities/course_import_schema.dart';
import '../entities/lesson_entity.dart';
import '../entities/unit_entity.dart';

abstract class CourseRepository {
  Future<List<CourseEntity>> getCourses({bool includeArchived = false});
  Future<CourseEntity?> getCourseById(String courseId);
  Future<List<UnitEntity>> getUnits(String courseId, {bool includeArchived = false});
  Future<List<LessonEntity>> getLessons(String unitId, {bool includeArchived = false});
  Future<LessonEntity?> getLessonById(String lessonId);

  // Streaming real-time updates from Firebase
  Stream<List<CourseEntity>> streamCourses({bool includeArchived = false});
  Stream<List<UnitEntity>> streamUnits(String courseId, {bool includeArchived = false});
  Stream<List<LessonEntity>> streamLessonsForCourse(String courseId, {bool includeArchived = false});
  Stream<List<LessonEntity>> streamLessons(String unitId, {bool includeArchived = false});
  Stream<LessonEntity?> streamLesson(String lessonId);
  void clearCache();

  // Admin Mutations
  Future<CourseEntity> createCourse(CourseEntity course);
  Future<void> updateCourse(CourseEntity course);
  Future<void> deleteCourse(String courseId);

  // Unit Mutations
  Future<UnitEntity> createUnit(UnitEntity unit);
  Future<void> updateUnit(UnitEntity unit);
  Future<void> deleteUnit(String unitId, String courseId, {bool softDelete = true});
  Future<void> reorderUnits(String courseId, List<UnitEntity> units);

  // Lesson Mutations
  Future<LessonEntity> createLesson(LessonEntity lesson);
  Future<void> updateLesson(LessonEntity lesson);
  Future<void> deleteLesson(
    String lessonId,
    String unitId, {
    String? courseId,
    bool softDelete = true,
  });
  Future<void> reorderLessons(String unitId, List<LessonEntity> lessons);

  // Ministry Curriculum Seeding
  Future<MinistrySeedPreview> loadMinistrySeedPreview();
  Future<MinistrySeedResult> importMinistrySeed({required String courseId});

  // Generic JSON Course Import
  Future<CourseEntity> importCourseFromJson({
    required CourseImportData importData,
    required String ownerAdminId,
  });
}

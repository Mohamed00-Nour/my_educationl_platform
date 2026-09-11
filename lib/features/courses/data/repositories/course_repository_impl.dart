import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/course_import_schema.dart';
import '../../domain/entities/lesson_entity.dart';
import '../../domain/entities/unit_entity.dart';
import '../../domain/repositories/course_repository.dart';
import '../datasources/course_remote_data_source.dart';
import '../datasources/ministry_course_seeder.dart';
import '../models/course_model.dart';
import '../models/lesson_model.dart';
import '../models/unit_model.dart';

class CourseRepositoryImpl implements CourseRepository {
  final CourseRemoteDataSource _remoteDataSource;

  CourseRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<CourseEntity>> getCourses({bool includeArchived = false}) async {
    try {
      return await _remoteDataSource.getCourses(
        includeArchived: includeArchived,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<CourseEntity?> getCourseById(String courseId) async {
    try {
      return await _remoteDataSource.getCourseById(courseId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<UnitEntity>> getUnits(String courseId, {bool includeArchived = false}) async {
    try {
      return await _remoteDataSource.getUnits(
        courseId,
        includeArchived: includeArchived,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<LessonEntity>> getLessons(String unitId, {bool includeArchived = false}) async {
    try {
      return await _remoteDataSource.getLessons(
        unitId,
        includeArchived: includeArchived,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<LessonEntity?> getLessonById(String lessonId) async {
    try {
      return await _remoteDataSource.getLessonById(lessonId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<CourseEntity>> streamCourses({bool includeArchived = false}) {
    return _remoteDataSource.streamCourses(includeArchived: includeArchived);
  }

  @override
  Stream<List<UnitEntity>> streamUnits(String courseId, {bool includeArchived = false}) {
    return _remoteDataSource.streamUnits(courseId, includeArchived: includeArchived);
  }

  @override
  Stream<List<LessonEntity>> streamLessonsForCourse(String courseId, {bool includeArchived = false}) {
    return _remoteDataSource.streamLessonsForCourse(courseId, includeArchived: includeArchived);
  }

  @override
  Stream<List<LessonEntity>> streamLessons(String unitId, {bool includeArchived = false}) {
    return _remoteDataSource.streamLessons(unitId, includeArchived: includeArchived);
  }

  @override
  Stream<LessonEntity?> streamLesson(String lessonId) {
    return _remoteDataSource.streamLesson(lessonId);
  }

  @override
  void clearCache() {
    _remoteDataSource.clearCache();
  }

  @override
  Future<CourseEntity> createCourse(CourseEntity course) async {
    try {
      return await _remoteDataSource.createCourse(
        CourseModel.fromEntity(course),
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateCourse(CourseEntity course) async {
    try {
      await _remoteDataSource.updateCourse(
        CourseModel.fromEntity(course),
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    try {
      await _remoteDataSource.deleteCourse(courseId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<UnitEntity> createUnit(UnitEntity unit) async {
    try {
      return await _remoteDataSource.createUnit(UnitModel.fromEntity(unit));
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateUnit(UnitEntity unit) async {
    try {
      await _remoteDataSource.updateUnit(UnitModel.fromEntity(unit));
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteUnit(String unitId, String courseId, {bool softDelete = true}) async {
    try {
      await _remoteDataSource.deleteUnit(unitId, courseId, softDelete: softDelete);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> reorderUnits(String courseId, List<UnitEntity> units) async {
    try {
      await _remoteDataSource.reorderUnits(
        courseId,
        units.map((u) => UnitModel.fromEntity(u)).toList(),
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<LessonEntity> createLesson(LessonEntity lesson) async {
    try {
      return await _remoteDataSource.createLesson(
        LessonModel.fromEntity(lesson),
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateLesson(LessonEntity lesson) async {
    try {
      await _remoteDataSource.updateLesson(LessonModel.fromEntity(lesson));
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteLesson(
    String lessonId,
    String unitId, {
    String? courseId,
    bool softDelete = true,
  }) async {
    try {
      await _remoteDataSource.deleteLesson(
        lessonId,
        unitId,
        courseId: courseId,
        softDelete: softDelete,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> reorderLessons(String unitId, List<LessonEntity> lessons) async {
    try {
      await _remoteDataSource.reorderLessons(
        unitId,
        lessons.map((l) => LessonModel.fromEntity(l)).toList(),
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<MinistrySeedPreview> loadMinistrySeedPreview() async {
    try {
      return await _remoteDataSource.loadMinistrySeedPreview();
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<MinistrySeedResult> importMinistrySeed({required String courseId}) async {
    try {
      return await _remoteDataSource.importMinistrySeed(courseId: courseId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<CourseEntity> importCourseFromJson({
    required CourseImportData importData,
    required String ownerAdminId,
  }) async {
    try {
      return await _remoteDataSource.importCourseStructure(
        importData: importData,
        ownerAdminId: ownerAdminId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}


import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/constants/app_constants.dart';
import 'package:instructor/features/courses/data/datasources/ministry_course_seeder.dart';
import 'package:instructor/features/courses/domain/entities/course_entity.dart';
import 'package:instructor/features/courses/domain/entities/course_import_schema.dart';
import 'package:instructor/features/courses/domain/entities/lesson_entity.dart';
import 'package:instructor/features/courses/domain/entities/lesson_material_entity.dart';
import 'package:instructor/features/courses/domain/entities/unit_entity.dart';
import 'package:instructor/features/courses/domain/repositories/course_repository.dart';
import 'package:instructor/features/courses/presentation/bloc/course_bloc.dart';

class FakeCourseRepository implements CourseRepository {
  final StreamController<List<CourseEntity>> coursesController =
      StreamController<List<CourseEntity>>.broadcast();
  final StreamController<List<UnitEntity>> unitsController =
      StreamController<List<UnitEntity>>.broadcast();
  final StreamController<List<LessonEntity>> lessonsController =
      StreamController<List<LessonEntity>>.broadcast();

  bool cacheCleared = false;

  @override
  Stream<List<CourseEntity>> streamCourses({bool includeArchived = false}) {
    return coursesController.stream;
  }

  @override
  Stream<List<UnitEntity>> streamUnits(String courseId, {bool includeArchived = false}) {
    return unitsController.stream;
  }

  @override
  Stream<List<LessonEntity>> streamLessonsForCourse(String courseId, {bool includeArchived = false}) {
    return lessonsController.stream;
  }

  @override
  Stream<List<LessonEntity>> streamLessons(String unitId, {bool includeArchived = false}) {
    return lessonsController.stream;
  }

  @override
  Stream<LessonEntity?> streamLesson(String lessonId) {
    return Stream.empty();
  }

  @override
  void clearCache() {
    cacheCleared = true;
  }

  @override
  Future<List<CourseEntity>> getCourses({bool includeArchived = false}) async => [];

  @override
  Future<CourseEntity?> getCourseById(String courseId) async => null;

  @override
  Future<List<UnitEntity>> getUnits(String courseId, {bool includeArchived = false}) async => [];

  @override
  Future<List<LessonEntity>> getLessons(String unitId, {bool includeArchived = false}) async => [];

  @override
  Future<LessonEntity?> getLessonById(String lessonId) async => null;

  @override
  Future<CourseEntity> createCourse(CourseEntity course) async => course;

  @override
  Future<void> updateCourse(CourseEntity course) async {}

  @override
  Future<void> deleteCourse(String courseId) async {}

  @override
  Future<UnitEntity> createUnit(UnitEntity unit) async => unit;

  @override
  Future<void> updateUnit(UnitEntity unit) async {}

  @override
  Future<void> deleteUnit(String unitId, String courseId, {bool softDelete = true}) async {}

  @override
  Future<void> reorderUnits(String courseId, List<UnitEntity> units) async {}

  @override
  Future<LessonEntity> createLesson(LessonEntity lesson) async => lesson;

  @override
  Future<void> updateLesson(LessonEntity lesson) async {}

  @override
  Future<void> deleteLesson(String lessonId, String unitId, {String? courseId, bool softDelete = true}) async {}

  @override
  Future<void> reorderLessons(String unitId, List<LessonEntity> lessons) async {}

  @override
  Future<MinistrySeedPreview> loadMinistrySeedPreview() => throw UnimplementedError();

  @override
  Future<MinistrySeedResult> importMinistrySeed({required String courseId}) => throw UnimplementedError();

  @override
  Future<CourseEntity> importCourseFromJson({
    required CourseImportData importData,
    required String ownerAdminId,
  }) => throw UnimplementedError();

  void dispose() {
    coursesController.close();
    unitsController.close();
    lessonsController.close();
  }
}

void main() {
  group('Course Real-Time Streaming & Materials Update Tests', () {
    late FakeCourseRepository repository;
    late CourseBloc courseBloc;

    final dummyCourse = CourseEntity(
      id: 'course-101',
      title: 'البرمجة والذكاء الاصطناعي',
      description: 'كورس البرمجة والذكاء الاصطناعي',
      targetGrade: StudentGrade.firstSecondary,
      academicYear: '2026-2027',
    );

    final dummyUnit = UnitEntity(
      id: 'unit-1',
      courseId: 'course-101',
      title: 'ما هي المعلومات؟',
      order: 1,
      bookStartPage: 7,
    );

    final initialLesson = LessonEntity(
      id: 'lesson-1',
      unitId: 'unit-1',
      courseId: 'course-101',
      title: 'المعلومات والوسائط',
      description: 'شرح مفهوم المعلومات والوسائط الرقمية',
      order: 1,
      materials: const [],
    );

    setUp(() {
      repository = FakeCourseRepository();
      courseBloc = CourseBloc(repository);
    });

    tearDown(() {
      courseBloc.close();
      repository.dispose();
    });

    test('StreamCoursesRequested listens to course stream and emits updated CourseLoaded', () async {
      final expectation = expectLater(
        courseBloc.stream,
        emits(predicate<CourseState>((state) {
          if (state is CourseLoaded) {
            return state.courses.length == 1 && state.courses.first.id == 'course-101';
          }
          return false;
        })),
      );

      courseBloc.add(const StreamCoursesRequested());
      await pumpEventQueue();
      repository.coursesController.add([dummyCourse]);

      await expectation;
    });

    test('StreamCourseDetailsRequested updates units, lessons and dynamically reflects newly added materials without reload', () async {
      final expectation = expectLater(
        courseBloc.stream,
        emitsInOrder([
          predicate<CourseState>((s) => s is CourseLoaded && s.units.length == 1),
          predicate<CourseState>((s) => s is CourseLoaded && (s.lessonsByUnit['unit-1']?.isNotEmpty ?? false) && s.lessonsByUnit['unit-1']!.first.materials.isEmpty),
          predicate<CourseState>((s) => s is CourseLoaded && (s.lessonsByUnit['unit-1']?.isNotEmpty ?? false) && s.lessonsByUnit['unit-1']!.first.materials.length == 1),
        ]),
      );

      courseBloc.add(const StreamCourseDetailsRequested('course-101'));
      await pumpEventQueue();

      // 1. Emit unit
      repository.unitsController.add([dummyUnit]);
      await pumpEventQueue();

      // 2. Emit initial lesson (0 materials)
      repository.lessonsController.add([initialLesson]);
      await pumpEventQueue();

      // 3. Admin adds a material (ملحق) to the lesson in Firebase Firestore
      final updatedLessonWithMaterial = initialLesson.copyWith(
        materials: const [
          LessonMaterialEntity(
            id: 'mat-1',
            title: 'كتاب الوزارة صـ 8',
            type: CourseMaterialType.ministryBook,
            url: 'https://example.com/book.pdf',
            startPage: 8,
            endPage: 12,
          ),
        ],
      );

      // Firestore stream pushes updated lessons in real-time
      repository.lessonsController.add([updatedLessonWithMaterial]);

      await expectation;
    });
  });
}

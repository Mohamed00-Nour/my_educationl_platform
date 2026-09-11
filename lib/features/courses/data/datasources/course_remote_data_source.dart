import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/course_import_schema.dart';
import '../models/course_model.dart';
import '../models/lesson_material_model.dart';
import '../models/lesson_model.dart';
import '../models/unit_model.dart';
import 'ministry_course_seeder.dart';

abstract class CourseRemoteDataSource {
  Future<List<CourseModel>> getCourses({bool includeArchived = false});
  Future<CourseModel?> getCourseById(String courseId);
  Future<List<UnitModel>> getUnits(String courseId, {bool includeArchived = false});
  Future<List<LessonModel>> getLessons(String unitId, {bool includeArchived = false});
  Future<LessonModel?> getLessonById(String lessonId);

  Future<CourseModel> createCourse(CourseModel course);
  Future<void> updateCourse(CourseModel course);
  Future<void> deleteCourse(String courseId);
  Future<UnitModel> createUnit(UnitModel unit);
  Future<void> updateUnit(UnitModel unit);
  Future<void> deleteUnit(String unitId, String courseId, {bool softDelete = true});
  Future<void> reorderUnits(String courseId, List<UnitModel> units);
  Future<LessonModel> createLesson(LessonModel lesson);
  Future<void> updateLesson(LessonModel lesson);
  Future<void> deleteLesson(String lessonId, String unitId, {String? courseId, bool softDelete = true});
  Future<void> reorderLessons(String unitId, List<LessonModel> lessons);

  // Streaming real-time updates from Firebase
  Stream<List<CourseModel>> streamCourses({bool includeArchived = false});
  Stream<List<UnitModel>> streamUnits(String courseId, {bool includeArchived = false});
  Stream<List<LessonModel>> streamLessonsForCourse(String courseId, {bool includeArchived = false});
  Stream<List<LessonModel>> streamLessons(String unitId, {bool includeArchived = false});
  Stream<LessonModel?> streamLesson(String lessonId);
  void clearCache();

  Future<MinistrySeedPreview> loadMinistrySeedPreview();
  Future<MinistrySeedResult> importMinistrySeed({required String courseId});

  Future<CourseModel> importCourseStructure({
    required CourseImportData importData,
    required String ownerAdminId,
  });
}

class CourseRemoteDataSourceImpl implements CourseRemoteDataSource {
  final FirebaseFirestore _firestore;
  final MinistryCourseSeeder _ministrySeeder;

  // In-memory caching to eliminate redundant Firestore reads
  final Map<String, List<CourseModel>> _coursesCache = {};
  final Map<String, List<UnitModel>> _unitsCache = {};
  final Map<String, List<LessonModel>> _lessonsCache = {};
  DateTime? _lastCoursesFetch;
  static const Duration _cacheTtl = Duration(minutes: 5);

  CourseRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    MinistryCourseSeeder? ministrySeeder,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _ministrySeeder = ministrySeeder ??
            MinistryCourseSeeder(firestore: firestore ?? FirebaseFirestore.instance);

  @override
  Future<List<CourseModel>> getCourses({bool includeArchived = false}) async {
    // Check cache TTL
    if (_lastCoursesFetch != null &&
        DateTime.now().difference(_lastCoursesFetch!) < _cacheTtl &&
        _coursesCache.containsKey('all')) {
      final cached = _coursesCache['all']!;
      return includeArchived
          ? cached
          : cached.where((c) => !c.isArchived).toList();
    }

    try {
      Query query = _firestore.collection(FirestoreCollections.courses);
      if (!includeArchived) {
        query = query.where('isArchived', isEqualTo: false);
      }

      final snapshot = await query.get();

      final courses =
          snapshot.docs.map((doc) => CourseModel.fromFirestore(doc)).toList();
      _coursesCache['all'] = courses;
      _lastCoursesFetch = DateTime.now();
      return courses;
    } catch (e) {
      throw ServerException('Failed to load courses: $e');
    }
  }

  @override
  Future<CourseModel?> getCourseById(String courseId) async {
    if (_coursesCache.containsKey('all')) {
      final match = _coursesCache['all']!.where((c) => c.id == courseId);
      if (match.isNotEmpty) return match.first;
    }

    try {
      final doc =
          await _firestore
              .collection(FirestoreCollections.courses)
              .doc(courseId)
              .get();
      if (!doc.exists) return null;
      return CourseModel.fromFirestore(doc);
    } catch (e) {
      throw ServerException('Failed to load course: $e');
    }
  }

  @override
  Future<List<UnitModel>> getUnits(String courseId, {bool includeArchived = false}) async {
    if (!includeArchived && _unitsCache.containsKey(courseId)) {
      return _unitsCache[courseId]!;
    }

    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.courses)
              .doc(courseId)
              .collection(FirestoreCollections.units)
              .orderBy('order')
              .get();

      final allUnits =
          snapshot.docs.map((doc) => UnitModel.fromFirestore(doc)).toList();
      final filteredUnits =
          includeArchived ? allUnits : allUnits.where((u) => !u.isArchived).toList();

      if (!includeArchived) {
        _unitsCache[courseId] = filteredUnits;
      }
      return filteredUnits;
    } catch (e) {
      throw ServerException('Failed to load units: $e');
    }
  }

  @override
  Future<List<LessonModel>> getLessons(String unitId, {bool includeArchived = false}) async {
    if (!includeArchived && _lessonsCache.containsKey(unitId)) {
      return _lessonsCache[unitId]!;
    }

    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.lessons)
              .where('unitId', isEqualTo: unitId)
              .orderBy('order')
              .get();

      final allLessons =
          snapshot.docs.map((doc) => LessonModel.fromFirestore(doc)).toList();
      final filteredLessons =
          includeArchived ? allLessons : allLessons.where((l) => !l.isArchived).toList();

      if (!includeArchived) {
        _lessonsCache[unitId] = filteredLessons;
      }
      return filteredLessons;
    } catch (e) {
      throw ServerException('Failed to load lessons: $e');
    }
  }

  @override
  void clearCache() {
    _coursesCache.clear();
    _unitsCache.clear();
    _lessonsCache.clear();
    _lastCoursesFetch = null;
  }

  @override
  Stream<List<CourseModel>> streamCourses({bool includeArchived = false}) {
    Query query = _firestore.collection(FirestoreCollections.courses);
    if (!includeArchived) {
      query = query.where('isArchived', isEqualTo: false);
    }

    return query.snapshots().map((snapshot) {
      final courses =
          snapshot.docs.map((doc) => CourseModel.fromFirestore(doc)).toList();
      _coursesCache['all'] = courses;
      _lastCoursesFetch = DateTime.now();
      return courses;
    });
  }

  @override
  Stream<List<UnitModel>> streamUnits(String courseId, {bool includeArchived = false}) {
    return _firestore
        .collection(FirestoreCollections.courses)
        .doc(courseId)
        .collection(FirestoreCollections.units)
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      final allUnits =
          snapshot.docs.map((doc) => UnitModel.fromFirestore(doc)).toList();
      final filteredUnits =
          includeArchived ? allUnits : allUnits.where((u) => !u.isArchived).toList();
      if (!includeArchived) {
        _unitsCache[courseId] = filteredUnits;
      }
      return filteredUnits;
    });
  }

  @override
  Stream<List<LessonModel>> streamLessonsForCourse(String courseId, {bool includeArchived = false}) {
    return _firestore
        .collection(FirestoreCollections.lessons)
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snapshot) {
      final allLessons =
          snapshot.docs.map((doc) => LessonModel.fromFirestore(doc)).toList();
      final filteredLessons =
          includeArchived ? allLessons : allLessons.where((l) => !l.isArchived).toList();
      filteredLessons.sort((a, b) => a.order.compareTo(b.order));

      final Map<String, List<LessonModel>> byUnit = {};
      for (final l in filteredLessons) {
        byUnit.putIfAbsent(l.unitId, () => []).add(l);
      }
      if (!includeArchived) {
        for (final entry in byUnit.entries) {
          _lessonsCache[entry.key] = entry.value;
        }
      }
      return filteredLessons;
    });
  }

  @override
  Stream<List<LessonModel>> streamLessons(String unitId, {bool includeArchived = false}) {
    return _firestore
        .collection(FirestoreCollections.lessons)
        .where('unitId', isEqualTo: unitId)
        .snapshots()
        .map((snapshot) {
      final allLessons =
          snapshot.docs.map((doc) => LessonModel.fromFirestore(doc)).toList();
      final filteredLessons =
          includeArchived ? allLessons : allLessons.where((l) => !l.isArchived).toList();
      filteredLessons.sort((a, b) => a.order.compareTo(b.order));
      if (!includeArchived) {
        _lessonsCache[unitId] = filteredLessons;
      }
      return filteredLessons;
    });
  }

  @override
  Future<LessonModel?> getLessonById(String lessonId) async {
    try {
      final doc =
          await _firestore
              .collection(FirestoreCollections.lessons)
              .doc(lessonId)
              .get();
      if (!doc.exists) return null;
      return LessonModel.fromFirestore(doc);
    } catch (e) {
      throw ServerException('Failed to load lesson: $e');
    }
  }

  @override
  Stream<LessonModel?> streamLesson(String lessonId) {
    return _firestore
        .collection(FirestoreCollections.lessons)
        .doc(lessonId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return LessonModel.fromFirestore(doc);
    });
  }

  @override
  Future<CourseModel> createCourse(CourseModel course) async {
    try {
      final docRef = _firestore.collection(FirestoreCollections.courses).doc();
      final modelToSave = CourseModel(
        id: docRef.id,
        title: course.title,
        description: course.description,
        academicYear: course.academicYear,
        targetGrade: course.targetGrade,
        ownerAdminId: course.ownerAdminId,
        unitCount: 0,
        studentCount: 0,
        createdAt: DateTime.now(),
      );
      await docRef.set(modelToSave.toMap());
      _coursesCache.clear();
      _lastCoursesFetch = null;
      return modelToSave;
    } catch (e) {
      throw ServerException('Failed to create course: $e');
    }
  }

  @override
  Future<void> updateCourse(CourseModel course) async {
    try {
      await _firestore
          .collection(FirestoreCollections.courses)
          .doc(course.id)
          .update(course.toUpdateMap());
      _coursesCache.clear();
      _lastCoursesFetch = null;
    } catch (e) {
      throw ServerException('Failed to update course: $e');
    }
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    try {
      // Find students who have this course in enrolledCourseIds and remove it
      final studentsWithCourse = await _firestore
          .collection(FirestoreCollections.users)
          .where('enrolledCourseIds', arrayContains: courseId)
          .get();

      final batch = _firestore.batch();
      for (final doc in studentsWithCourse.docs) {
        batch.update(doc.reference, {
          'enrolledCourseIds': FieldValue.arrayRemove([courseId]),
        });
      }
      batch.delete(
        _firestore.collection(FirestoreCollections.courses).doc(courseId),
      );
      await batch.commit();

      _coursesCache.clear();
      _lastCoursesFetch = null;
    } catch (e) {
      throw ServerException('Failed to delete course: $e');
    }
  }

  @override
  Future<UnitModel> createUnit(UnitModel unit) async {
    try {
      final docRef =
          _firestore
              .collection(FirestoreCollections.courses)
              .doc(unit.courseId)
              .collection(FirestoreCollections.units)
              .doc();

      final modelToSave = UnitModel(
        id: docRef.id,
        courseId: unit.courseId,
        title: unit.title,
        description: unit.description,
        order: unit.order,
        lessonCount: 0,
        isPublished: unit.isPublished,
        isArchived: unit.isArchived,
        bookStartPage: unit.bookStartPage,
      );

      await docRef.set(modelToSave.toMap());

      // Increment unitCount on course document
      await _firestore
          .collection(FirestoreCollections.courses)
          .doc(unit.courseId)
          .update({'unitCount': FieldValue.increment(1)});

      _unitsCache.remove(unit.courseId);
      _coursesCache.clear();
      return modelToSave;
    } catch (e) {
      throw ServerException('Failed to create unit: $e');
    }
  }

  @override
  Future<void> updateUnit(UnitModel unit) async {
    try {
      await _firestore
          .collection(FirestoreCollections.courses)
          .doc(unit.courseId)
          .collection(FirestoreCollections.units)
          .doc(unit.id)
          .update(unit.toMap());

      _unitsCache.remove(unit.courseId);
    } catch (e) {
      throw ServerException('Failed to update unit: $e');
    }
  }

  @override
  Future<void> deleteUnit(String unitId, String courseId, {bool softDelete = true}) async {
    try {
      final unitRef = _firestore
          .collection(FirestoreCollections.courses)
          .doc(courseId)
          .collection(FirestoreCollections.units)
          .doc(unitId);

      // Find all lessons for this unit
      final lessonsSnapshot = await _firestore
          .collection(FirestoreCollections.lessons)
          .where('unitId', isEqualTo: unitId)
          .get();

      final batch = _firestore.batch();

      if (softDelete) {
        batch.update(unitRef, {'isArchived': true});
        for (final doc in lessonsSnapshot.docs) {
          batch.update(doc.reference, {'isArchived': true});
        }
      } else {
        batch.delete(unitRef);
        for (final doc in lessonsSnapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      // Decrement unitCount on course
      batch.update(
        _firestore.collection(FirestoreCollections.courses).doc(courseId),
        {'unitCount': FieldValue.increment(-1)},
      );

      await batch.commit();

      _unitsCache.remove(courseId);
      _lessonsCache.remove(unitId);
      _coursesCache.clear();
    } catch (e) {
      throw ServerException('Failed to delete unit: $e');
    }
  }

  @override
  Future<void> reorderUnits(String courseId, List<UnitModel> units) async {
    try {
      final batch = _firestore.batch();
      for (int i = 0; i < units.length; i++) {
        final ref = _firestore
            .collection(FirestoreCollections.courses)
            .doc(courseId)
            .collection(FirestoreCollections.units)
            .doc(units[i].id);
        batch.update(ref, {'order': i + 1});
      }
      await batch.commit();
      _unitsCache.remove(courseId);
    } catch (e) {
      throw ServerException('Failed to reorder units: $e');
    }
  }

  @override
  Future<LessonModel> createLesson(LessonModel lesson) async {
    try {
      final docRef = _firestore.collection(FirestoreCollections.lessons).doc();
      final modelToSave = LessonModel(
        id: docRef.id,
        courseId: lesson.courseId,
        unitId: lesson.unitId,
        title: lesson.title,
        description: lesson.description,
        order: lesson.order,
        materials: lesson.materials,
        quizId: lesson.quizId,
        isPublished: lesson.isPublished,
        isArchived: lesson.isArchived,
        notes: lesson.notes,
        bookStartPage: lesson.bookStartPage,
      );

      await docRef.set(modelToSave.toMap());

      // Update unit lesson count
      await _firestore
          .collection(FirestoreCollections.courses)
          .doc(lesson.courseId)
          .collection(FirestoreCollections.units)
          .doc(lesson.unitId)
          .update({'lessonCount': FieldValue.increment(1)});

      _lessonsCache.remove(lesson.unitId);
      _unitsCache.remove(lesson.courseId);
      return modelToSave;
    } catch (e) {
      throw ServerException('Failed to create lesson: $e');
    }
  }

  @override
  Future<void> updateLesson(LessonModel lesson) async {
    try {
      await _firestore
          .collection(FirestoreCollections.lessons)
          .doc(lesson.id)
          .update(lesson.toMap());
      _lessonsCache.remove(lesson.unitId);
    } catch (e) {
      throw ServerException('Failed to update lesson: $e');
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
      final lessonRef =
          _firestore.collection(FirestoreCollections.lessons).doc(lessonId);

      final batch = _firestore.batch();
      if (softDelete) {
        batch.update(lessonRef, {'isArchived': true});
      } else {
        batch.delete(lessonRef);
      }

      if (courseId != null && courseId.isNotEmpty) {
        final unitRef = _firestore
            .collection(FirestoreCollections.courses)
            .doc(courseId)
            .collection(FirestoreCollections.units)
            .doc(unitId);
        batch.update(unitRef, {'lessonCount': FieldValue.increment(-1)});
      }

      await batch.commit();
      _lessonsCache.remove(unitId);
      if (courseId != null) {
        _unitsCache.remove(courseId);
      }
    } catch (e) {
      throw ServerException('Failed to delete lesson: $e');
    }
  }

  @override
  Future<void> reorderLessons(String unitId, List<LessonModel> lessons) async {
    try {
      final batch = _firestore.batch();
      for (int i = 0; i < lessons.length; i++) {
        final ref =
            _firestore.collection(FirestoreCollections.lessons).doc(lessons[i].id);
        batch.update(ref, {'order': i + 1});
      }
      await batch.commit();
      _lessonsCache.remove(unitId);
    } catch (e) {
      throw ServerException('Failed to reorder lessons: $e');
    }
  }

  @override
  Future<MinistrySeedPreview> loadMinistrySeedPreview() async {
    return _ministrySeeder.loadPreview();
  }

  @override
  Future<MinistrySeedResult> importMinistrySeed({required String courseId}) async {
    final result = await _ministrySeeder.seedCourseStructure(courseId: courseId);
    _unitsCache.remove(courseId);
    _lessonsCache.clear();
    _coursesCache.clear();
    return result;
  }

  @override
  Future<CourseModel> importCourseStructure({
    required CourseImportData importData,
    required String ownerAdminId,
  }) async {
    try {
      final courseDocRef = _firestore.collection(FirestoreCollections.courses).doc();

      // Create CourseModel with forced authenticated ownerAdminId
      final courseModel = CourseModel(
        id: courseDocRef.id,
        title: importData.title,
        description: importData.description,
        academicYear: importData.academicYear,
        targetGrade: importData.targetGrade,
        ownerAdminId: ownerAdminId, // Never trust JSON, enforce caller Admin UID
        unitCount: importData.units.length,
        studentCount: 0,
        createdAt: DateTime.now(),
      );

      WriteBatch currentBatch = _firestore.batch();
      int batchOps = 0;

      Future<void> flushBatch() async {
        if (batchOps > 0) {
          await currentBatch.commit();
          currentBatch = _firestore.batch();
          batchOps = 0;
        }
      }

      // 1. Queue Course doc write
      currentBatch.set(courseDocRef, courseModel.toMap());
      batchOps++;

      // 2. Queue Units and Lessons
      for (final u in importData.units) {
        final unitDocRef = _firestore
            .collection(FirestoreCollections.courses)
            .doc(courseDocRef.id)
            .collection(FirestoreCollections.units)
            .doc();

        final unitMap = {
          'courseId': courseDocRef.id,
          'title': u.title,
          'description': u.description,
          'order': u.order,
          if (u.bookStartPage != null) 'bookStartPage': u.bookStartPage,
          'lessonCount': u.lessons.length,
          'isPublished': true,
          'isArchived': false,
          'createdAt': FieldValue.serverTimestamp(),
        };

        currentBatch.set(unitDocRef, unitMap);
        batchOps++;
        if (batchOps >= 400) await flushBatch();

        for (final l in u.lessons) {
          final lessonDocRef =
              _firestore.collection(FirestoreCollections.lessons).doc();

          final lessonMap = {
            'courseId': courseDocRef.id,
            'unitId': unitDocRef.id, // Stable relational ID
            'title': l.title,
            'description': l.description,
            'order': l.order,
            if (l.bookStartPage != null) 'bookStartPage': l.bookStartPage,
            if (l.notes != null) 'notes': l.notes,
            'isPublished': true,
            'isArchived': false,
            'materials': l.materials
                .map((m) => LessonMaterialModel.fromEntity(m).toMap())
                .toList(),
            'createdAt': FieldValue.serverTimestamp(),
          };

          currentBatch.set(lessonDocRef, lessonMap);
          batchOps++;
          if (batchOps >= 400) await flushBatch();
        }
      }

      await flushBatch();

      _coursesCache.clear();
      _lastCoursesFetch = null;
      return courseModel;
    } catch (e) {
      throw ServerException('Failed to import course structure: $e');
    }
  }
}

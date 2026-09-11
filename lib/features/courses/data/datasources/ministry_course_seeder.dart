import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';

class MinistrySeedPreview {
  final String title;
  final String grade;
  final String academicYear;
  final String sourceType;
  final String notes;
  final int unitsCount;
  final int lessonsCount;
  final List<String> sampleUnitTitles;

  const MinistrySeedPreview({
    required this.title,
    required this.grade,
    required this.academicYear,
    required this.sourceType,
    required this.notes,
    required this.unitsCount,
    required this.lessonsCount,
    required this.sampleUnitTitles,
  });
}

class MinistrySeedResult {
  final int unitsImported;
  final int lessonsImported;

  const MinistrySeedResult({
    required this.unitsImported,
    required this.lessonsImported,
  });
}

class MinistryCourseSeeder {
  static const String seedAssetPath =
      'assets/seed/ministry_course_structure_sec1_programming_ai.json';

  final FirebaseFirestore _firestore;

  MinistryCourseSeeder({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Loads and parses the seed JSON to provide a preview before confirmation.
  Future<MinistrySeedPreview> loadPreview() async {
    try {
      final jsonString = await rootBundle.loadString(seedAssetPath);
      final Map<String, dynamic> data = json.decode(jsonString);

      final source = (data['source'] as Map<String, dynamic>?) ?? {};
      final course = (data['course'] as Map<String, dynamic>?) ?? {};
      final units = (course['units'] as List<dynamic>?) ?? [];

      int totalLessons = 0;
      final List<String> sampleUnits = [];

      for (final u in units) {
        if (u is Map<String, dynamic>) {
          sampleUnits.add(u['title'] as String? ?? '');
          final lessons = (u['lessons'] as List<dynamic>?) ?? [];
          totalLessons += lessons.length;
        }
      }

      return MinistrySeedPreview(
        title:
            (course['title'] as String?) ??
            (source['title'] as String?) ??
            'منهج الوزارة',
        grade: (source['grade'] as String?) ?? 'الصف الأول الثانوي',
        academicYear: (source['academicYear'] as String?) ?? '2025-2026',
        sourceType: (source['sourceType'] as String?) ?? 'وزارة التربية والتعليم',
        notes: (source['notes'] as String?) ?? '',
        unitsCount: units.length,
        lessonsCount: totalLessons,
        sampleUnitTitles: sampleUnits,
      );
    } catch (e) {
      throw ServerException('Failed to load ministry curriculum seed: $e');
    }
  }

  /// Checks if the target course already has existing units in Firestore.
  Future<int> checkExistingUnitsCount(String courseId) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.courses)
              .doc(courseId)
              .collection(FirestoreCollections.units)
              .where('isArchived', isEqualTo: false)
              .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Imports the seed JSON structure into the specified course document.
  /// All Units and Lessons receive stable Firestore document IDs.
  Future<MinistrySeedResult> seedCourseStructure({
    required String courseId,
  }) async {
    try {
      final jsonString = await rootBundle.loadString(seedAssetPath);
      final Map<String, dynamic> data = json.decode(jsonString);

      final course = (data['course'] as Map<String, dynamic>?) ?? {};
      final units = (course['units'] as List<dynamic>?) ?? [];

      final batch = _firestore.batch();
      int importedUnits = 0;
      int importedLessons = 0;

      for (int uIdx = 0; uIdx < units.length; uIdx++) {
        final u = units[uIdx] as Map<String, dynamic>;
        final lessons = (u['lessons'] as List<dynamic>?) ?? [];

        // Generate stable DocumentReference for the Unit
        final unitDocRef =
            _firestore
                .collection(FirestoreCollections.courses)
                .doc(courseId)
                .collection(FirestoreCollections.units)
                .doc();

        final unitData = {
          'courseId': courseId,
          'title': (u['title'] as String?)?.trim() ?? 'وحدة بدون عنوان',
          'description': (u['description'] as String?)?.trim() ?? '',
          'order': (u['order'] as num?)?.toInt() ?? (uIdx + 1),
          'bookStartPage': (u['bookStartPage'] as num?)?.toInt(),
          'lessonCount': lessons.length,
          'isPublished': true,
          'isArchived': false,
          'createdAt': FieldValue.serverTimestamp(),
        };

        batch.set(unitDocRef, unitData);
        importedUnits++;

        // Create Lessons referencing this Unit's stable ID
        for (int lIdx = 0; lIdx < lessons.length; lIdx++) {
          final l = lessons[lIdx] as Map<String, dynamic>;

          final lessonDocRef =
              _firestore.collection(FirestoreCollections.lessons).doc();

          final lessonData = {
            'courseId': courseId,
            'unitId': unitDocRef.id,
            'title': (l['title'] as String?)?.trim() ?? 'درس بدون عنوان',
            'description': (l['description'] as String?)?.trim() ?? '',
            'order': (l['order'] as num?)?.toInt() ?? (lIdx + 1),
            'bookStartPage': (l['bookStartPage'] as num?)?.toInt(),
            'isPublished': true,
            'isArchived': false,
            'materials': <Map<String, dynamic>>[],
            'createdAt': FieldValue.serverTimestamp(),
          };

          batch.set(lessonDocRef, lessonData);
          importedLessons++;
        }
      }

      // Update unitCount on the course document
      final courseRef = _firestore
          .collection(FirestoreCollections.courses)
          .doc(courseId);
      batch.update(courseRef, {'unitCount': importedUnits});

      await batch.commit();

      return MinistrySeedResult(
        unitsImported: importedUnits,
        lessonsImported: importedLessons,
      );
    } catch (e) {
      throw ServerException('Failed to import ministry course structure: $e');
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/attendance_model.dart';

abstract class AttendanceRemoteDataSource {
  Future<List<AttendanceModel>> getAttendanceForSession({
    required String courseId,
    required String sessionDate,
  });

  Future<List<AttendanceModel>> getAttendanceForStudent({
    required String studentId,
    required String courseId,
  });

  Future<List<Map<String, String>>> getEnrolledStudents({
    required String courseId,
  });

  Future<void> saveAttendanceBatch(List<AttendanceModel> records);
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final FirebaseFirestore _firestore;

  AttendanceRemoteDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<AttendanceModel>> getAttendanceForSession({
    required String courseId,
    required String sessionDate,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.attendance)
              .where('courseId', isEqualTo: courseId)
              .where('sessionDate', isEqualTo: sessionDate)
              .get();

      return snapshot.docs
          .map((d) => AttendanceModel.fromFirestore(d))
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch session attendance: $e');
    }
  }

  @override
  Future<List<AttendanceModel>> getAttendanceForStudent({
    required String studentId,
    required String courseId,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.attendance)
              .where('studentId', isEqualTo: studentId)
              .where('courseId', isEqualTo: courseId)
              .get();

      return snapshot.docs
          .map((d) => AttendanceModel.fromFirestore(d))
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch student attendance: $e');
    }
  }

  @override
  Future<List<Map<String, String>>> getEnrolledStudents({
    required String courseId,
  }) async {
    try {
      // Only return students who are enrolled in this specific course
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.users)
              .where('role', isEqualTo: AppConstants.roleStudent)
              .where('enrolledCourseIds', arrayContains: courseId)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final name = (data['displayName'] as String?)?.trim();
        final email = (data['email'] as String?)?.trim();
        return {
          'id': doc.id,
          'name':
              (name != null && name.isNotEmpty)
                  ? name
                  : (email != null && email.isNotEmpty ? email : 'Student'),
        };
      }).toList();
    } catch (e) {
      throw ServerException('Failed to fetch enrolled students: $e');
    }
  }

  @override
  Future<void> saveAttendanceBatch(List<AttendanceModel> records) async {
    try {
      final batch = _firestore.batch();
      for (final r in records) {
        final docId = '${r.courseId}_${r.sessionDate}_${r.studentId}';
        final docRef = _firestore
            .collection(FirestoreCollections.attendance)
            .doc(docId);
        batch.set(docRef, r.toMap());
      }
      await batch.commit();
    } catch (e) {
      throw ServerException('Failed to save attendance records: $e');
    }
  }
}

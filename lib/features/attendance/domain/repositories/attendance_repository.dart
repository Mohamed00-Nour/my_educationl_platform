import '../entities/attendance_record.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceRecord>> getAttendanceForSession({
    required String courseId,
    required String sessionDate,
  });

  Future<List<AttendanceRecord>> getAttendanceForStudent({
    required String studentId,
    required String courseId,
  });

  Future<List<Map<String, String>>> getEnrolledStudents({
    required String courseId,
  });

  Future<void> saveAttendanceBatch(List<AttendanceRecord> records);
}

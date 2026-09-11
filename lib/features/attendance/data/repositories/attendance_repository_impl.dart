import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_data_source.dart';
import '../models/attendance_model.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource _remoteDataSource;

  AttendanceRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<AttendanceRecord>> getAttendanceForSession({
    required String courseId,
    required String sessionDate,
  }) async {
    try {
      return await _remoteDataSource.getAttendanceForSession(
        courseId: courseId,
        sessionDate: sessionDate,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceForStudent({
    required String studentId,
    required String courseId,
  }) async {
    try {
      return await _remoteDataSource.getAttendanceForStudent(
        studentId: studentId,
        courseId: courseId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<Map<String, String>>> getEnrolledStudents({
    required String courseId,
  }) async {
    try {
      return await _remoteDataSource.getEnrolledStudents(courseId: courseId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> saveAttendanceBatch(List<AttendanceRecord> records) async {
    try {
      final models = records.map((r) => AttendanceModel.fromEntity(r)).toList();
      await _remoteDataSource.saveAttendanceBatch(models);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

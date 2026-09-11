import '../../domain/entities/student_progress_summary.dart';

abstract class ProgressRepository {
  Future<StudentProgressSummary> getStudentProgressSummary({
    required String studentId,
    required String studentName,
    required String courseId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  });
}

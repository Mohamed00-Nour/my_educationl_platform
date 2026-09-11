import '../entities/evaluation_adjustment.dart';

abstract class EvaluationRepository {
  Future<List<EvaluationAdjustment>> getAdjustmentsForStudent({
    required String studentId,
    required String courseId,
  });

  Future<List<EvaluationAdjustment>> getAdjustmentsForCourse(String courseId);

  Future<EvaluationAdjustment> addAdjustment(EvaluationAdjustment adjustment);

  Future<void> deleteAdjustment(String id);
}

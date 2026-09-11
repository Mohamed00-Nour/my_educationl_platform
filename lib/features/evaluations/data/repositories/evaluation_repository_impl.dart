import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/evaluation_adjustment.dart';
import '../../domain/repositories/evaluation_repository.dart';
import '../datasources/evaluation_remote_data_source.dart';
import '../models/evaluation_adjustment_model.dart';

class EvaluationRepositoryImpl implements EvaluationRepository {
  final EvaluationRemoteDataSource _remoteDataSource;

  EvaluationRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<EvaluationAdjustment>> getAdjustmentsForStudent({
    required String studentId,
    required String courseId,
  }) async {
    try {
      return await _remoteDataSource.getAdjustmentsForStudent(
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
  Future<List<EvaluationAdjustment>> getAdjustmentsForCourse(
    String courseId,
  ) async {
    try {
      return await _remoteDataSource.getAdjustmentsForCourse(courseId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<EvaluationAdjustment> addAdjustment(
    EvaluationAdjustment adjustment,
  ) async {
    try {
      return await _remoteDataSource.addAdjustment(
        EvaluationAdjustmentModel.fromEntity(adjustment),
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteAdjustment(String id) async {
    try {
      await _remoteDataSource.deleteAdjustment(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

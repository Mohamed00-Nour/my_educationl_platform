import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/admin_join_code_entity.dart';
import '../../domain/entities/admin_overview_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/join_code_repository.dart';
import '../datasources/join_code_remote_data_source.dart';

class JoinCodeRepositoryImpl implements JoinCodeRepository {
  final JoinCodeRemoteDataSource _remoteDataSource;

  JoinCodeRepositoryImpl(this._remoteDataSource);

  @override
  Future<AdminJoinCodeEntity> validateJoinCode(String code) async {
    try {
      return await _remoteDataSource.validateJoinCode(code);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, e.code);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw AuthFailure('Failed to validate teacher code: $e');
    }
  }

  @override
  Future<AdminJoinCodeEntity?> getJoinCodeForAdmin(String adminId) async {
    try {
      return await _remoteDataSource.getJoinCodeForAdmin(adminId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<AdminJoinCodeEntity> generateOrRegenerateCode({
    required String adminId,
    required String adminName,
    DateTime? expiresAt,
    required String createdBy,
  }) async {
    try {
      return await _remoteDataSource.generateOrRegenerateCode(
        adminId: adminId,
        adminName: adminName,
        expiresAt: expiresAt,
        createdBy: createdBy,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> toggleCodeStatus({
    required String codeHash,
    required bool isActive,
  }) async {
    try {
      await _remoteDataSource.toggleCodeStatus(
        codeHash: codeHash,
        isActive: isActive,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateCodeExpiry({
    required String codeHash,
    DateTime? expiresAt,
  }) async {
    try {
      await _remoteDataSource.updateCodeExpiry(
        codeHash: codeHash,
        expiresAt: expiresAt,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<AdminOverviewEntity>> getAllAdminsOverview() async {
    try {
      return await _remoteDataSource.getAllAdminsOverview();
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> transferStudent({
    required String studentId,
    required String newAdminId,
  }) async {
    try {
      await _remoteDataSource.transferStudent(
        studentId: studentId,
        newAdminId: newAdminId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<UserEntity>> getStudentsForAdmin(String adminId) async {
    try {
      return await _remoteDataSource.getStudentsForAdmin(adminId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

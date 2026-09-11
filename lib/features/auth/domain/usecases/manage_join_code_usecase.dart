import '../entities/admin_join_code_entity.dart';
import '../repositories/join_code_repository.dart';

class ManageJoinCodeUseCase {
  final JoinCodeRepository _repository;

  ManageJoinCodeUseCase(this._repository);

  Future<AdminJoinCodeEntity?> getCodeForAdmin(String adminId) {
    return _repository.getJoinCodeForAdmin(adminId);
  }

  Future<AdminJoinCodeEntity> generateOrRegenerate({
    required String adminId,
    required String adminName,
    DateTime? expiresAt,
    required String createdBy,
  }) {
    return _repository.generateOrRegenerateCode(
      adminId: adminId,
      adminName: adminName,
      expiresAt: expiresAt,
      createdBy: createdBy,
    );
  }

  Future<void> toggleStatus({
    required String codeHash,
    required bool isActive,
  }) {
    return _repository.toggleCodeStatus(codeHash: codeHash, isActive: isActive);
  }

  Future<void> updateExpiry({required String codeHash, DateTime? expiresAt}) {
    return _repository.updateCodeExpiry(
      codeHash: codeHash,
      expiresAt: expiresAt,
    );
  }
}

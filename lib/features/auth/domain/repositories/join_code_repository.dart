import '../entities/admin_join_code_entity.dart';
import '../entities/admin_overview_entity.dart';
import '../entities/user_entity.dart';

abstract class JoinCodeRepository {
  /// Validates a student-supplied join code.
  /// Resolves and returns the active [AdminJoinCodeEntity] if valid.
  /// Throws [Failure] if code is missing, invalid, inactive, or expired.
  Future<AdminJoinCodeEntity> validateJoinCode(String code);

  /// Retrieves the active (or latest) join code record for a specific Admin.
  Future<AdminJoinCodeEntity?> getJoinCodeForAdmin(String adminId);

  /// Generates a new unique 6-digit Join Code for [adminId], deactivating any previously active codes.
  Future<AdminJoinCodeEntity> generateOrRegenerateCode({
    required String adminId,
    required String adminName,
    DateTime? expiresAt,
    required String createdBy,
  });

  /// Toggles the active status of a Join Code record.
  Future<void> toggleCodeStatus({
    required String codeHash,
    required bool isActive,
  });

  /// Updates or clears the expiration date of a Join Code record.
  Future<void> updateCodeExpiry({
    required String codeHash,
    DateTime? expiresAt,
  });

  /// Retrieves a comprehensive overview of all Admins, their active Join Codes, and assigned student counts.
  /// Accessible only to Super Admins.
  Future<List<AdminOverviewEntity>> getAllAdminsOverview();

  /// Transfers a student from their current Admin to [newAdminId].
  /// Non-destructively preserves historical records.
  /// Accessible only to Super Admins.
  Future<void> transferStudent({
    required String studentId,
    required String newAdminId,
  });

  /// Retrieves all students currently assigned to [adminId] (`ownerAdminId == adminId`).
  Future<List<UserEntity>> getStudentsForAdmin(String adminId);
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/join_code_utils.dart';
import '../../domain/entities/admin_overview_entity.dart';
import '../models/admin_join_code_model.dart';
import '../models/user_model.dart';

abstract class JoinCodeRemoteDataSource {
  Future<AdminJoinCodeModel> validateJoinCode(String code);
  Future<AdminJoinCodeModel?> getJoinCodeForAdmin(String adminId);
  Future<AdminJoinCodeModel> generateOrRegenerateCode({
    required String adminId,
    required String adminName,
    DateTime? expiresAt,
    required String createdBy,
  });
  Future<void> toggleCodeStatus({
    required String codeHash,
    required bool isActive,
  });
  Future<void> updateCodeExpiry({
    required String codeHash,
    DateTime? expiresAt,
  });
  Future<List<AdminOverviewEntity>> getAllAdminsOverview();
  Future<void> transferStudent({
    required String studentId,
    required String newAdminId,
  });
  Future<List<UserModel>> getStudentsForAdmin(String adminId);
}

class JoinCodeRemoteDataSourceImpl implements JoinCodeRemoteDataSource {
  final FirebaseFirestore _firestore;

  JoinCodeRemoteDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<AdminJoinCodeModel> validateJoinCode(String code) async {
    final cleanCode = JoinCodeUtils.normalizeCode(code);
    if (cleanCode.isEmpty) {
      throw const AuthException(
        'Invalid teacher code. Please check the code and try again.',
        'invalid-join-code',
      );
    }

    try {
      final codeHash = JoinCodeUtils.hashJoinCode(cleanCode);
      final doc =
          await _firestore
              .collection(FirestoreCollections.adminJoinCodes)
              .doc(codeHash)
              .get();

      if (!doc.exists) {
        throw const AuthException(
          'Invalid teacher code. Please check the code and try again.',
          'invalid-join-code',
        );
      }

      final model = AdminJoinCodeModel.fromFirestore(doc);

      if (!model.isActive) {
        throw const AuthException(
          'This teacher code has been deactivated. Please contact your instructor.',
          'inactive-join-code',
        );
      }

      if (model.isExpired) {
        throw const AuthException(
          'This teacher code has expired. Please request a new code from your instructor.',
          'expired-join-code',
        );
      }

      return model;
    } on AuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(
        'Failed to validate teacher code: ${e.message ?? e.code}',
        e.code,
      );
    } catch (e) {
      throw ServerException('Failed to validate teacher code: $e');
    }
  }

  @override
  Future<AdminJoinCodeModel?> getJoinCodeForAdmin(String adminId) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.adminJoinCodes)
              .where('adminId', isEqualTo: adminId)
              .get();

      if (snapshot.docs.isEmpty) return null;

      // Find active code first, otherwise return the most recent one
      final models =
          snapshot.docs.map((d) => AdminJoinCodeModel.fromFirestore(d)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final active = models.where((m) => m.isActive && !m.isExpired);
      if (active.isNotEmpty) {
        return active.first;
      }
      return models.first;
    } catch (e) {
      throw ServerException('Failed to load admin join code: $e');
    }
  }

  @override
  Future<AdminJoinCodeModel> generateOrRegenerateCode({
    required String adminId,
    required String adminName,
    DateTime? expiresAt,
    required String createdBy,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Deactivate existing active codes for this admin
      final existingActive =
          await _firestore
              .collection(FirestoreCollections.adminJoinCodes)
              .where('adminId', isEqualTo: adminId)
              .where('isActive', isEqualTo: true)
              .get();

      for (final doc in existingActive.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Generate new unique 6-digit code
      final rawCode = JoinCodeUtils.generate6DigitCode();
      final salt = JoinCodeUtils.generateSalt();
      final codeHash = JoinCodeUtils.hashJoinCode(rawCode);
      final now = DateTime.now();

      final newModel = AdminJoinCodeModel(
        id: codeHash,
        adminId: adminId,
        adminName: adminName,
        code: rawCode,
        codeHash: codeHash,
        salt: salt,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        expiresAt: expiresAt,
        createdBy: createdBy,
      );

      final newDocRef = _firestore
          .collection(FirestoreCollections.adminJoinCodes)
          .doc(codeHash);

      batch.set(newDocRef, newModel.toMap());

      await batch.commit();
      return newModel;
    } catch (e) {
      throw ServerException('Failed to generate admin join code: $e');
    }
  }

  @override
  Future<void> toggleCodeStatus({
    required String codeHash,
    required bool isActive,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.adminJoinCodes)
          .doc(codeHash)
          .update({
            'isActive': isActive,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw ServerException('Failed to update join code status: $e');
    }
  }

  @override
  Future<void> updateCodeExpiry({
    required String codeHash,
    DateTime? expiresAt,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.adminJoinCodes)
          .doc(codeHash)
          .update({
            'expiresAt':
                expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw ServerException('Failed to update join code expiry: $e');
    }
  }

  @override
  Future<List<AdminOverviewEntity>> getAllAdminsOverview() async {
    try {
      // 1. Fetch all admin users
      final usersSnap =
          await _firestore
              .collection(FirestoreCollections.users)
              .where(
                'role',
                whereIn: [AppConstants.roleAdmin, AppConstants.roleSuperAdmin],
              )
              .get();

      // 2. Fetch all active join codes
      final codesSnap =
          await _firestore
              .collection(FirestoreCollections.adminJoinCodes)
              .get();

      final allCodes =
          codesSnap.docs
              .map((d) => AdminJoinCodeModel.fromFirestore(d))
              .toList();

      // 3. Fetch all students to aggregate student count per admin
      final studentsSnap =
          await _firestore
              .collection(FirestoreCollections.users)
              .where('role', isEqualTo: AppConstants.roleStudent)
              .get();

      final studentCountsByAdmin = <String, int>{};
      for (final doc in studentsSnap.docs) {
        final data = doc.data();
        final ownerId = data['ownerAdminId'] as String?;
        if (ownerId != null && ownerId.isNotEmpty) {
          studentCountsByAdmin[ownerId] =
              (studentCountsByAdmin[ownerId] ?? 0) + 1;
        }
      }

      final overviews = <AdminOverviewEntity>[];
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final adminId = doc.id;
        final name = (data['displayName'] as String?) ?? 'Admin';
        final email = (data['email'] as String?) ?? '';

        final adminCodes =
            allCodes.where((c) => c.adminId == adminId).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final activeCode =
            adminCodes.where((c) => c.isActive && !c.isExpired).firstOrNull ??
            adminCodes.firstOrNull;

        overviews.add(
          AdminOverviewEntity(
            adminId: adminId,
            displayName: name,
            email: email,
            activeJoinCode: activeCode,
            studentCount: studentCountsByAdmin[adminId] ?? 0,
            createdAt:
                (data['createdAt'] is Timestamp)
                    ? (data['createdAt'] as Timestamp).toDate()
                    : null,
          ),
        );
      }

      return overviews;
    } catch (e) {
      throw ServerException('Failed to load admins overview: $e');
    }
  }

  @override
  Future<void> transferStudent({
    required String studentId,
    required String newAdminId,
  }) async {
    try {
      // Historical attempts, attendance records, and evaluations maintain their original ownership context
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(studentId)
          .update({
            'ownerAdminId': newAdminId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw ServerException('Failed to transfer student: $e');
    }
  }

  @override
  Future<List<UserModel>> getStudentsForAdmin(String adminId) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.users)
              .where('role', isEqualTo: AppConstants.roleStudent)
              .where('ownerAdminId', isEqualTo: adminId)
              .get();

      return snapshot.docs.map((d) => UserModel.fromFirestore(d)).toList();
    } catch (e) {
      throw ServerException('Failed to load students for admin: $e');
    }
  }
}

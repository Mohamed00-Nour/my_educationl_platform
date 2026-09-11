import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/errors/exceptions.dart';
import 'package:instructor/core/errors/failures.dart';
import 'package:instructor/core/utils/join_code_utils.dart';
import 'package:instructor/features/auth/data/datasources/join_code_remote_data_source.dart';
import 'package:instructor/features/auth/data/models/admin_join_code_model.dart';
import 'package:instructor/features/auth/data/models/user_model.dart';
import 'package:instructor/features/auth/data/repositories/join_code_repository_impl.dart';
import 'package:instructor/features/auth/domain/entities/admin_overview_entity.dart';
import 'package:instructor/features/auth/domain/entities/user_entity.dart';
import 'package:instructor/features/auth/domain/usecases/get_admins_overview_usecase.dart';
import 'package:instructor/features/auth/domain/usecases/manage_join_code_usecase.dart';
import 'package:instructor/features/auth/domain/usecases/transfer_student_usecase.dart';
import 'package:instructor/features/auth/domain/usecases/validate_join_code_usecase.dart';

// In-memory fake remote data source for deterministic testing
class FakeJoinCodeRemoteDataSource implements JoinCodeRemoteDataSource {
  final Map<String, AdminJoinCodeModel> codesByHash = {};
  final Map<String, UserModel> usersById = {};

  @override
  Future<AdminJoinCodeModel> validateJoinCode(String code) async {
    final cleanCode = JoinCodeUtils.normalizeCode(code);
    if (cleanCode.isEmpty) {
      throw const AuthException(
        'Invalid teacher code. Please check the code and try again.',
        'invalid-join-code',
      );
    }
    final hash = JoinCodeUtils.hashJoinCode(cleanCode);
    final model = codesByHash[hash];
    if (model == null) {
      throw const AuthException(
        'Invalid teacher code. Please check the code and try again.',
        'invalid-join-code',
      );
    }
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
  }

  @override
  Future<AdminJoinCodeModel?> getJoinCodeForAdmin(String adminId) async {
    final matching =
        codesByHash.values.where((c) => c.adminId == adminId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (matching.isEmpty) return null;
    return matching.where((c) => c.isActive && !c.isExpired).firstOrNull ??
        matching.first;
  }

  @override
  Future<AdminJoinCodeModel> generateOrRegenerateCode({
    required String adminId,
    required String adminName,
    DateTime? expiresAt,
    required String createdBy,
  }) async {
    // Deactivate previous codes
    for (final key in codesByHash.keys.toList()) {
      if (codesByHash[key]!.adminId == adminId && codesByHash[key]!.isActive) {
        codesByHash[key] = AdminJoinCodeModel(
          id: codesByHash[key]!.id,
          adminId: codesByHash[key]!.adminId,
          adminName: codesByHash[key]!.adminName,
          code: codesByHash[key]!.code,
          codeHash: codesByHash[key]!.codeHash,
          salt: codesByHash[key]!.salt,
          isActive: false,
          createdAt: codesByHash[key]!.createdAt,
          updatedAt: DateTime.now(),
          expiresAt: codesByHash[key]!.expiresAt,
          createdBy: codesByHash[key]!.createdBy,
        );
      }
    }

    final rawCode = JoinCodeUtils.generate6DigitCode();
    final salt = JoinCodeUtils.generateSalt();
    final hash = JoinCodeUtils.hashJoinCode(rawCode);
    final now = DateTime.now();

    final newModel = AdminJoinCodeModel(
      id: hash,
      adminId: adminId,
      adminName: adminName,
      code: rawCode,
      codeHash: hash,
      salt: salt,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      expiresAt: expiresAt,
      createdBy: createdBy,
    );

    codesByHash[hash] = newModel;
    return newModel;
  }

  @override
  Future<void> toggleCodeStatus({
    required String codeHash,
    required bool isActive,
  }) async {
    final existing = codesByHash[codeHash];
    if (existing != null) {
      codesByHash[codeHash] = AdminJoinCodeModel(
        id: existing.id,
        adminId: existing.adminId,
        adminName: existing.adminName,
        code: existing.code,
        codeHash: existing.codeHash,
        salt: existing.salt,
        isActive: isActive,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        expiresAt: existing.expiresAt,
        createdBy: existing.createdBy,
      );
    }
  }

  @override
  Future<void> updateCodeExpiry({
    required String codeHash,
    DateTime? expiresAt,
  }) async {
    final existing = codesByHash[codeHash];
    if (existing != null) {
      codesByHash[codeHash] = AdminJoinCodeModel(
        id: existing.id,
        adminId: existing.adminId,
        adminName: existing.adminName,
        code: existing.code,
        codeHash: existing.codeHash,
        salt: existing.salt,
        isActive: existing.isActive,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        expiresAt: expiresAt,
        createdBy: existing.createdBy,
      );
    }
  }

  @override
  Future<List<AdminOverviewEntity>> getAllAdminsOverview() async {
    final admins = usersById.values.where((u) => u.role.isAdmin).toList();

    return admins.map((a) {
      final code =
          codesByHash.values
              .where((c) => c.adminId == a.id && c.isActive)
              .firstOrNull;
      final studentCount =
          usersById.values
              .where((u) => u.role.isStudent && u.ownerAdminId == a.id)
              .length;

      return AdminOverviewEntity(
        adminId: a.id,
        displayName: a.displayName,
        email: a.email,
        activeJoinCode: code,
        studentCount: studentCount,
      );
    }).toList();
  }

  @override
  Future<void> transferStudent({
    required String studentId,
    required String newAdminId,
  }) async {
    final student = usersById[studentId];
    if (student != null) {
      usersById[studentId] = student.copyWithModel(ownerAdminId: newAdminId);
    }
  }

  @override
  Future<List<UserModel>> getStudentsForAdmin(String adminId) async {
    return usersById.values
        .where((u) => u.role.isStudent && u.ownerAdminId == adminId)
        .toList();
  }
}

void main() {
  group('JoinCodeUtils Tests', () {
    test('generate6DigitCode generates valid 6-digit numeric string', () {
      final code = JoinCodeUtils.generate6DigitCode();
      expect(code.length, equals(6));
      expect(int.tryParse(code), isNotNull);
      expect(int.parse(code), inInclusiveRange(100000, 999999));
    });

    test(
      'normalizeCode removes whitespace, dashes and converts to uppercase',
      () {
        expect(JoinCodeUtils.normalizeCode(' 482-731 '), equals('482731'));
        expect(JoinCodeUtils.normalizeCode('abc - 123'), equals('ABC123'));
      },
    );

    test('hashJoinCode is deterministic', () {
      const code = '482731';
      final hash1 = JoinCodeUtils.hashJoinCode(code);
      final hash2 = JoinCodeUtils.hashJoinCode(' 482-731 ');
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 hex length
    });

    test(
      'verifyJoinCode returns true for exact code and false for incorrect',
      () {
        const code = '981245';
        final hash = JoinCodeUtils.hashJoinCode(code);

        expect(JoinCodeUtils.verifyJoinCode('981245', hash), isTrue);
        expect(JoinCodeUtils.verifyJoinCode(' 981-245 ', hash), isTrue);
        expect(JoinCodeUtils.verifyJoinCode('000000', hash), isFalse);
      },
    );
  });

  group('JoinCodeRepository & Validation Tests', () {
    late FakeJoinCodeRemoteDataSource fakeDataSource;
    late JoinCodeRepositoryImpl repository;
    late ValidateJoinCodeUseCase validateUseCase;
    late ManageJoinCodeUseCase manageUseCase;
    late TransferStudentUseCase transferUseCase;
    late GetAdminsOverviewUseCase overviewUseCase;

    setUp(() {
      fakeDataSource = FakeJoinCodeRemoteDataSource();
      repository = JoinCodeRepositoryImpl(fakeDataSource);
      validateUseCase = ValidateJoinCodeUseCase(repository);
      manageUseCase = ManageJoinCodeUseCase(repository);
      transferUseCase = TransferStudentUseCase(repository);
      overviewUseCase = GetAdminsOverviewUseCase(repository);
    });

    test('valid code assigns correct Admin', () async {
      final created = await manageUseCase.generateOrRegenerate(
        adminId: 'admin_1',
        adminName: 'مستر أحمد علي',
        createdBy: 'admin_1',
      );

      final result = await validateUseCase.call(created.code);
      expect(result.adminId, equals('admin_1'));
      expect(result.adminName, equals('مستر أحمد علي'));
      expect(result.isValid, isTrue);
    });

    test(
      'invalid code is rejected with clear user-facing error message',
      () async {
        expect(
          () => validateUseCase.call('999999'),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.message,
              'message',
              contains('Invalid teacher code'),
            ),
          ),
        );
      },
    );

    test('inactive code is rejected', () async {
      final created = await manageUseCase.generateOrRegenerate(
        adminId: 'admin_1',
        adminName: 'مستر أحمد علي',
        createdBy: 'admin_1',
      );

      await manageUseCase.toggleStatus(
        codeHash: created.codeHash,
        isActive: false,
      );

      expect(
        () => validateUseCase.call(created.code),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            contains('deactivated'),
          ),
        ),
      );
    });

    test('expired code is rejected if expiry is used', () async {
      final created = await manageUseCase.generateOrRegenerate(
        adminId: 'admin_1',
        adminName: 'مستر أحمد علي',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        createdBy: 'admin_1',
      );

      expect(
        () => validateUseCase.call(created.code),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            contains('expired'),
          ),
        ),
      );
    });

    test(
      'regenerated code invalidates previous code while preserving student assignment',
      () async {
        // 1. Initial code for Admin A
        final firstCode = await manageUseCase.generateOrRegenerate(
          adminId: 'admin_A',
          adminName: 'Teacher Alpha',
          createdBy: 'admin_A',
        );

        // Student registers using first code
        final validation = await validateUseCase.call(firstCode.code);
        expect(validation.adminId, equals('admin_A'));
        fakeDataSource.usersById['student_1'] = const UserModel(
          id: 'student_1',
          email: 'student1@test.com',
          displayName: 'Tariq',
          role: UserRole.student,
          ownerAdminId: 'admin_A',
        );

        // 2. Admin A regenerates code
        final secondCode = await manageUseCase.generateOrRegenerate(
          adminId: 'admin_A',
          adminName: 'Teacher Alpha',
          createdBy: 'admin_A',
        );

        // Previous code is now rejected
        expect(
          () => validateUseCase.call(firstCode.code),
          throwsA(isA<AuthFailure>()),
        );

        // New code succeeds
        final newValidation = await validateUseCase.call(secondCode.code);
        expect(newValidation.adminId, equals('admin_A'));

        // Existing student remains assigned to admin_A!
        final student = fakeDataSource.usersById['student_1'];
        expect(student?.ownerAdminId, equals('admin_A'));
      },
    );

    test(
      'Super Admin student transfer reassigns ownerAdminId non-destructively',
      () async {
        // Setup two admins and one student
        fakeDataSource.usersById['admin_A'] = const UserModel(
          id: 'admin_A',
          email: 'a@test.com',
          displayName: 'Teacher A',
          role: UserRole.admin,
        );
        fakeDataSource.usersById['admin_B'] = const UserModel(
          id: 'admin_B',
          email: 'b@test.com',
          displayName: 'Teacher B',
          role: UserRole.admin,
        );
        fakeDataSource.usersById['student_1'] = const UserModel(
          id: 'student_1',
          email: 'student@test.com',
          displayName: 'Kareem',
          role: UserRole.student,
          ownerAdminId: 'admin_A',
        );

        // Verify student belongs to admin_A initially
        var studentsA = await overviewUseCase.getStudentsForAdmin('admin_A');
        var studentsB = await overviewUseCase.getStudentsForAdmin('admin_B');
        expect(studentsA.length, equals(1));
        expect(studentsB.length, equals(0));

        // Super Admin transfers student to Admin B
        await transferUseCase.call(
          studentId: 'student_1',
          newAdminId: 'admin_B',
        );

        // Verify student now belongs to admin_B
        studentsA = await overviewUseCase.getStudentsForAdmin('admin_A');
        studentsB = await overviewUseCase.getStudentsForAdmin('admin_B');
        expect(studentsA.length, equals(0));
        expect(studentsB.length, equals(1));
        expect(studentsB.first.id, equals('student_1'));
      },
    );

    test(
      'Super Admin overview computes accurate student count per admin',
      () async {
        fakeDataSource.usersById['admin_1'] = const UserModel(
          id: 'admin_1',
          email: 'admin1@test.com',
          displayName: 'Admin One',
          role: UserRole.admin,
        );
        fakeDataSource.usersById['admin_2'] = const UserModel(
          id: 'admin_2',
          email: 'admin2@test.com',
          displayName: 'Admin Two',
          role: UserRole.admin,
        );

        fakeDataSource.usersById['s1'] = const UserModel(
          id: 's1',
          email: 's1@test.com',
          displayName: 'S1',
          role: UserRole.student,
          ownerAdminId: 'admin_1',
        );
        fakeDataSource.usersById['s2'] = const UserModel(
          id: 's2',
          email: 's2@test.com',
          displayName: 'S2',
          role: UserRole.student,
          ownerAdminId: 'admin_1',
        );
        fakeDataSource.usersById['s3'] = const UserModel(
          id: 's3',
          email: 's3@test.com',
          displayName: 'S3',
          role: UserRole.student,
          ownerAdminId: 'admin_2',
        );

        final overviews = await overviewUseCase.call();
        expect(overviews.length, equals(2));

        final admin1Overview = overviews.firstWhere(
          (o) => o.adminId == 'admin_1',
        );
        final admin2Overview = overviews.firstWhere(
          (o) => o.adminId == 'admin_2',
        );

        expect(admin1Overview.studentCount, equals(2));
        expect(admin2Overview.studentCount, equals(1));
      },
    );

    test(
      'UserRole enum correctly distinguishes superAdmin, admin, and student',
      () {
        expect(UserRole.fromString('superAdmin'), equals(UserRole.superAdmin));
        expect(UserRole.fromString('superadmin'), equals(UserRole.superAdmin));
        expect(UserRole.fromString('admin'), equals(UserRole.admin));
        expect(UserRole.fromString('teacher'), equals(UserRole.admin));
        expect(UserRole.fromString('student'), equals(UserRole.student));

        expect(UserRole.superAdmin.isSuperAdmin, isTrue);
        expect(UserRole.superAdmin.isAdmin, isTrue);
        expect(UserRole.superAdmin.isStudent, isFalse);

        expect(UserRole.admin.isSuperAdmin, isFalse);
        expect(UserRole.admin.isAdmin, isTrue);
        expect(UserRole.admin.isStrictAdmin, isTrue);
        expect(UserRole.admin.isStudent, isFalse);

        expect(UserRole.student.isAdmin, isFalse);
        expect(UserRole.student.isStudent, isTrue);
      },
    );
  });
}

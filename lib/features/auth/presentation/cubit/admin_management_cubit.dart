import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/admin_join_code_entity.dart';
import '../../domain/entities/admin_overview_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/get_admins_overview_usecase.dart';
import '../../domain/usecases/manage_join_code_usecase.dart';
import '../../domain/usecases/transfer_student_usecase.dart';

abstract class AdminManagementState extends Equatable {
  const AdminManagementState();
  @override
  List<Object?> get props => [];
}

class AdminManagementInitial extends AdminManagementState {}

class AdminManagementLoading extends AdminManagementState {}

class AdminJoinCodeLoaded extends AdminManagementState {
  final AdminJoinCodeEntity? joinCode;
  final bool isOperating;
  final String? actionSuccessMessage;

  const AdminJoinCodeLoaded({
    this.joinCode,
    this.isOperating = false,
    this.actionSuccessMessage,
  });

  AdminJoinCodeLoaded copyWith({
    AdminJoinCodeEntity? joinCode,
    bool? isOperating,
    String? actionSuccessMessage,
    bool clearMessage = false,
  }) {
    return AdminJoinCodeLoaded(
      joinCode: joinCode ?? this.joinCode,
      isOperating: isOperating ?? this.isOperating,
      actionSuccessMessage:
          clearMessage
              ? null
              : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }

  @override
  List<Object?> get props => [joinCode, isOperating, actionSuccessMessage];
}

class SuperAdminOverviewLoaded extends AdminManagementState {
  final List<AdminOverviewEntity> admins;
  final bool isOperating;
  final String? actionSuccessMessage;
  final Map<String, List<UserEntity>> adminStudents;

  const SuperAdminOverviewLoaded({
    required this.admins,
    this.isOperating = false,
    this.actionSuccessMessage,
    this.adminStudents = const {},
  });

  SuperAdminOverviewLoaded copyWith({
    List<AdminOverviewEntity>? admins,
    bool? isOperating,
    String? actionSuccessMessage,
    Map<String, List<UserEntity>>? adminStudents,
    bool clearMessage = false,
  }) {
    return SuperAdminOverviewLoaded(
      admins: admins ?? this.admins,
      isOperating: isOperating ?? this.isOperating,
      actionSuccessMessage:
          clearMessage
              ? null
              : (actionSuccessMessage ?? this.actionSuccessMessage),
      adminStudents: adminStudents ?? this.adminStudents,
    );
  }

  @override
  List<Object?> get props => [
    admins,
    isOperating,
    actionSuccessMessage,
    adminStudents,
  ];
}

class AdminManagementError extends AdminManagementState {
  final String message;
  const AdminManagementError(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminManagementCubit extends Cubit<AdminManagementState> {
  final ManageJoinCodeUseCase _manageJoinCodeUseCase;
  final GetAdminsOverviewUseCase _getAdminsOverviewUseCase;
  final TransferStudentUseCase _transferStudentUseCase;

  AdminManagementCubit({
    required ManageJoinCodeUseCase manageJoinCodeUseCase,
    required GetAdminsOverviewUseCase getAdminsOverviewUseCase,
    required TransferStudentUseCase transferStudentUseCase,
  }) : _manageJoinCodeUseCase = manageJoinCodeUseCase,
       _getAdminsOverviewUseCase = getAdminsOverviewUseCase,
       _transferStudentUseCase = transferStudentUseCase,
       super(AdminManagementInitial());

  // ================= ADMIN ACTIONS =================

  /// Loads the active join code for a specific Admin. Auto-generates one if missing.
  Future<void> loadAdminJoinCode({
    required String adminId,
    required String adminName,
    bool autoGenerateIfMissing = true,
  }) async {
    emit(AdminManagementLoading());
    try {
      var code = await _manageJoinCodeUseCase.getCodeForAdmin(adminId);
      if (code == null && autoGenerateIfMissing) {
        code = await _manageJoinCodeUseCase.generateOrRegenerate(
          adminId: adminId,
          adminName: adminName,
          createdBy: adminId,
        );
      }
      emit(AdminJoinCodeLoaded(joinCode: code));
    } catch (e) {
      emit(AdminManagementError('فشل تحميل كود الانضمام: $e'));
    }
  }

  /// Regenerates a fresh 6-digit Join Code for [adminId].
  Future<void> regenerateJoinCode({
    required String adminId,
    required String adminName,
    DateTime? expiresAt,
    required String createdBy,
  }) async {
    final currentState = state;
    if (currentState is AdminJoinCodeLoaded) {
      emit(currentState.copyWith(isOperating: true));
    }
    try {
      final newCode = await _manageJoinCodeUseCase.generateOrRegenerate(
        adminId: adminId,
        adminName: adminName,
        expiresAt: expiresAt,
        createdBy: createdBy,
      );
      emit(
        AdminJoinCodeLoaded(
          joinCode: newCode,
          actionSuccessMessage: 'تم إنشاء كود انضمام جديد بنجاح.',
        ),
      );
    } catch (e) {
      emit(AdminManagementError('فشل إعادة إنشاء كود الانضمام: $e'));
    }
  }

  /// Toggles active/inactive state of the join code.
  Future<void> toggleCodeStatus({
    required String codeHash,
    required bool isActive,
  }) async {
    final currentState = state;
    if (currentState is AdminJoinCodeLoaded) {
      emit(currentState.copyWith(isOperating: true));
    }
    try {
      await _manageJoinCodeUseCase.toggleStatus(
        codeHash: codeHash,
        isActive: isActive,
      );
      if (currentState is AdminJoinCodeLoaded &&
          currentState.joinCode != null) {
        final updated = currentState.joinCode!.copyWith(isActive: isActive);
        emit(
          AdminJoinCodeLoaded(
            joinCode: updated,
            actionSuccessMessage:
                isActive ? 'تم تفعيل كود الانضمام.' : 'تم إيقاف كود الانضمام.',
          ),
        );
      }
    } catch (e) {
      emit(AdminManagementError('فشل تعديل حالة الكود: $e'));
    }
  }

  // ================= SUPER ADMIN ACTIONS =================

  /// Loads global overview of all Admins for Super Admin.
  Future<void> loadSuperAdminOverview() async {
    emit(AdminManagementLoading());
    try {
      final overview = await _getAdminsOverviewUseCase.call();
      emit(SuperAdminOverviewLoaded(admins: overview));
    } catch (e) {
      emit(AdminManagementError('فشل تحميل بيانات المشرفين: $e'));
    }
  }

  /// Loads assigned students for a specific Admin (e.g. for transfer modal).
  Future<void> loadStudentsForAdmin(String adminId) async {
    final currentState = state;
    if (currentState is! SuperAdminOverviewLoaded) return;

    try {
      final students = await _getAdminsOverviewUseCase.getStudentsForAdmin(
        adminId,
      );
      final updatedMap = Map<String, List<UserEntity>>.from(
        currentState.adminStudents,
      );
      updatedMap[adminId] = students;
      emit(currentState.copyWith(adminStudents: updatedMap));
    } catch (e) {
      emit(AdminManagementError('فشل تحميل قائمة الطلاب: $e'));
    }
  }

  /// Transfers a student from their current Admin to [newAdminId].
  Future<void> transferStudent({
    required String studentId,
    required String newAdminId,
  }) async {
    final currentState = state;
    if (currentState is SuperAdminOverviewLoaded) {
      emit(currentState.copyWith(isOperating: true));
    }
    try {
      await _transferStudentUseCase.call(
        studentId: studentId,
        newAdminId: newAdminId,
      );
      // Refresh overview
      final updatedAdmins = await _getAdminsOverviewUseCase.call();
      emit(
        SuperAdminOverviewLoaded(
          admins: updatedAdmins,
          actionSuccessMessage: 'تم نقل الطالب بنجاح إلى المشرف المحدد.',
        ),
      );
    } catch (e) {
      emit(AdminManagementError('فشل نقل الطالب: $e'));
    }
  }

  /// Super Admin can regenerate code for any Admin.
  Future<void> superAdminRegenerateCode({
    required String targetAdminId,
    required String targetAdminName,
    DateTime? expiresAt,
    required String superAdminId,
  }) async {
    final currentState = state;
    if (currentState is SuperAdminOverviewLoaded) {
      emit(currentState.copyWith(isOperating: true));
    }
    try {
      await _manageJoinCodeUseCase.generateOrRegenerate(
        adminId: targetAdminId,
        adminName: targetAdminName,
        expiresAt: expiresAt,
        createdBy: superAdminId,
      );
      final updatedAdmins = await _getAdminsOverviewUseCase.call();
      emit(
        SuperAdminOverviewLoaded(
          admins: updatedAdmins,
          actionSuccessMessage:
              'تم تجديد كود الانضمام للمشرف $targetAdminName بنجاح.',
        ),
      );
    } catch (e) {
      emit(AdminManagementError('فشل تجديد كود المشرف: $e'));
    }
  }

  /// Super Admin can toggle code status for any Admin.
  Future<void> superAdminToggleCode({
    required String codeHash,
    required bool isActive,
  }) async {
    final currentState = state;
    if (currentState is SuperAdminOverviewLoaded) {
      emit(currentState.copyWith(isOperating: true));
    }
    try {
      await _manageJoinCodeUseCase.toggleStatus(
        codeHash: codeHash,
        isActive: isActive,
      );
      final updatedAdmins = await _getAdminsOverviewUseCase.call();
      emit(
        SuperAdminOverviewLoaded(
          admins: updatedAdmins,
          actionSuccessMessage:
              isActive ? 'تم تفعيل الكود بنجاح.' : 'تم تعطيل الكود بنجاح.',
        ),
      );
    } catch (e) {
      emit(AdminManagementError('فشل تعديل حالة الكود: $e'));
    }
  }

  /// Super Admin can set or remove expiration for any Admin's code.
  Future<void> superAdminUpdateExpiry({
    required String codeHash,
    DateTime? expiresAt,
  }) async {
    final currentState = state;
    if (currentState is SuperAdminOverviewLoaded) {
      emit(currentState.copyWith(isOperating: true));
    }
    try {
      await _manageJoinCodeUseCase.updateExpiry(
        codeHash: codeHash,
        expiresAt: expiresAt,
      );
      final updatedAdmins = await _getAdminsOverviewUseCase.call();
      emit(
        SuperAdminOverviewLoaded(
          admins: updatedAdmins,
          actionSuccessMessage:
              expiresAt != null
                  ? 'تم تعيين موعد انتهاء الكود.'
                  : 'تم إلغاء تاريخ انتهاء الكود.',
        ),
      );
    } catch (e) {
      emit(AdminManagementError('فشل تعديل تاريخ الانتهاء: $e'));
    }
  }
}

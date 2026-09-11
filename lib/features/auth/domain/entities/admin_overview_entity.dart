import 'package:equatable/equatable.dart';
import 'admin_join_code_entity.dart';

class AdminOverviewEntity extends Equatable {
  final String adminId;
  final String displayName;
  final String email;
  final AdminJoinCodeEntity? activeJoinCode;
  final int studentCount;
  final DateTime? createdAt;

  const AdminOverviewEntity({
    required this.adminId,
    required this.displayName,
    required this.email,
    this.activeJoinCode,
    this.studentCount = 0,
    this.createdAt,
  });

  AdminOverviewEntity copyWith({
    String? adminId,
    String? displayName,
    String? email,
    AdminJoinCodeEntity? activeJoinCode,
    int? studentCount,
    DateTime? createdAt,
    bool clearCode = false,
  }) {
    return AdminOverviewEntity(
      adminId: adminId ?? this.adminId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      activeJoinCode:
          clearCode ? null : (activeJoinCode ?? this.activeJoinCode),
      studentCount: studentCount ?? this.studentCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    adminId,
    displayName,
    email,
    activeJoinCode,
    studentCount,
    createdAt,
  ];
}

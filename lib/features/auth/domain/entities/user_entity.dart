import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

enum UserRole {
  superAdmin,
  admin,
  student;

  static UserRole fromString(String? role) {
    final clean = role?.toLowerCase().trim();
    if (clean == 'superadmin') {
      return UserRole.superAdmin;
    }
    if (clean == 'admin' || clean == 'teacher') {
      return UserRole.admin;
    }
    return UserRole.student;
  }

  String toValue() {
    switch (this) {
      case UserRole.superAdmin:
        return 'superAdmin';
      case UserRole.admin:
        return 'admin';
      case UserRole.student:
        return 'student';
    }
  }

  bool get isSuperAdmin => this == UserRole.superAdmin;
  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;
  bool get isStrictAdmin => this == UserRole.admin;
  bool get isStudent => this == UserRole.student;
}

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final StudentGrade? grade;
  final String? ownerAdminId;
  final List<String> enrolledCourseIds;
  final List<String> fcmTokens;
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.grade,
    this.ownerAdminId,
    this.enrolledCourseIds = const [],
    this.fcmTokens = const [],
    this.createdAt,
  });

  bool get isSuperAdmin => role.isSuperAdmin;
  bool get isAdmin => role.isAdmin;
  bool get isStudent => role.isStudent;

  UserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    StudentGrade? grade,
    String? ownerAdminId,
    List<String>? enrolledCourseIds,
    List<String>? fcmTokens,
    DateTime? createdAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      grade: grade ?? this.grade,
      ownerAdminId: ownerAdminId ?? this.ownerAdminId,
      enrolledCourseIds: enrolledCourseIds ?? this.enrolledCourseIds,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    role,
    grade,
    ownerAdminId,
    enrolledCourseIds,
    fcmTokens,
    createdAt,
  ];
}

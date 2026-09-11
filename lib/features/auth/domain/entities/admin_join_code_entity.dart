import 'package:equatable/equatable.dart';

class AdminJoinCodeEntity extends Equatable {
  final String id;
  final String adminId;
  final String adminName;
  final String code;
  final String codeHash;
  final String salt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final String? createdBy;

  const AdminJoinCodeEntity({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.code,
    required this.codeHash,
    required this.salt,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.createdBy,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isValid => isActive && !isExpired;

  AdminJoinCodeEntity copyWith({
    String? id,
    String? adminId,
    String? adminName,
    String? code,
    String? codeHash,
    String? salt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    String? createdBy,
    bool clearExpiry = false,
  }) {
    return AdminJoinCodeEntity(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      code: code ?? this.code,
      codeHash: codeHash ?? this.codeHash,
      salt: salt ?? this.salt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  List<Object?> get props => [
    id,
    adminId,
    adminName,
    code,
    codeHash,
    salt,
    isActive,
    createdAt,
    updatedAt,
    expiresAt,
    createdBy,
  ];
}

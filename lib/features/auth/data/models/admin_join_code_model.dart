import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/admin_join_code_entity.dart';

class AdminJoinCodeModel extends AdminJoinCodeEntity {
  const AdminJoinCodeModel({
    required super.id,
    required super.adminId,
    required super.adminName,
    required super.code,
    required super.codeHash,
    required super.salt,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
    super.expiresAt,
    super.createdBy,
  });

  factory AdminJoinCodeModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AdminJoinCodeModel.fromMap(doc.id, data);
  }

  factory AdminJoinCodeModel.fromMap(String id, Map<String, dynamic> map) {
    return AdminJoinCodeModel(
      id: id,
      adminId: map['adminId'] as String? ?? '',
      adminName: map['adminName'] as String? ?? '',
      code: map['code'] as String? ?? '',
      codeHash: map['codeHash'] as String? ?? '',
      salt: map['salt'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
      expiresAt: _parseDate(map['expiresAt']),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'adminName': adminName,
      'code': code,
      'codeHash': codeHash,
      'salt': salt,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

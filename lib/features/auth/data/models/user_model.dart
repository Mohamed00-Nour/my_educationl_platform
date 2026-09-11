import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.displayName,
    required super.role,
    super.grade,
    super.ownerAdminId,
    super.enrolledCourseIds,
    super.fcmTokens,
    super.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: UserRole.fromString(data['role'] as String?),
      grade: StudentGrade.fromString(data['grade'] as String?),
      ownerAdminId: data['ownerAdminId'] as String?,
      enrolledCourseIds: List<String>.from(data['enrolledCourseIds'] ?? []),
      fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
      createdAt:
          (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: UserRole.fromString(map['role'] as String?),
      grade: StudentGrade.fromString(map['grade'] as String?),
      ownerAdminId: map['ownerAdminId'] as String?,
      enrolledCourseIds: List<String>.from(map['enrolledCourseIds'] ?? []),
      fcmTokens: List<String>.from(map['fcmTokens'] ?? []),
      createdAt:
          (map['createdAt'] is Timestamp)
              ? (map['createdAt'] as Timestamp).toDate()
              : (map['createdAt'] is String)
              ? DateTime.tryParse(map['createdAt'])
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.toValue(),
      'grade': grade?.toValue(),
      if (ownerAdminId != null) 'ownerAdminId': ownerAdminId,
      'enrolledCourseIds': enrolledCourseIds,
      'fcmTokens': fcmTokens,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWithModel({
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
    return UserModel(
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
}

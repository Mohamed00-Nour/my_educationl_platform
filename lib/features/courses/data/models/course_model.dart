import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/course_entity.dart';

class CourseModel extends CourseEntity {
  const CourseModel({
    required super.id,
    required super.title,
    required super.description,
    required super.academicYear,
    super.targetGrade,
    super.unitCount,
    super.studentCount,
    super.isArchived,
    super.createdAt,
    super.ownerAdminId,
  });

  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CourseModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      academicYear: data['academicYear'] as String? ?? '',
      targetGrade: StudentGrade.fromString(data['targetGrade'] as String?),
      unitCount: (data['unitCount'] as num?)?.toInt() ?? 0,
      studentCount: (data['studentCount'] as num?)?.toInt() ?? 0,
      isArchived: data['isArchived'] as bool? ?? false,
      ownerAdminId: data['ownerAdminId'] as String?,
      createdAt:
          (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'academicYear': academicYear,
      'targetGrade': targetGrade?.toValue(),
      'unitCount': unitCount,
      'studentCount': studentCount,
      'isArchived': isArchived,
      if (ownerAdminId != null) 'ownerAdminId': ownerAdminId,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title,
      'description': description,
      'academicYear': academicYear,
      'targetGrade': targetGrade?.toValue(),
      if (ownerAdminId != null) 'ownerAdminId': ownerAdminId,
    };
  }

  factory CourseModel.fromEntity(CourseEntity entity) {
    return CourseModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      academicYear: entity.academicYear,
      targetGrade: entity.targetGrade,
      unitCount: entity.unitCount,
      studentCount: entity.studentCount,
      isArchived: entity.isArchived,
      createdAt: entity.createdAt,
      ownerAdminId: entity.ownerAdminId,
    );
  }
}

import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class CourseEntity extends Equatable {
  final String id;
  final String title;
  final String description;
  final String academicYear;
  final StudentGrade? targetGrade;
  final int unitCount;
  final int studentCount;
  final bool isArchived;
  final DateTime? createdAt;
  final String? ownerAdminId;

  const CourseEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.academicYear,
    this.targetGrade,
    this.unitCount = 0,
    this.studentCount = 0,
    this.isArchived = false,
    this.createdAt,
    this.ownerAdminId,
  });

  CourseEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? academicYear,
    StudentGrade? targetGrade,
    int? unitCount,
    int? studentCount,
    bool? isArchived,
    DateTime? createdAt,
    String? ownerAdminId,
  }) {
    return CourseEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      academicYear: academicYear ?? this.academicYear,
      targetGrade: targetGrade ?? this.targetGrade,
      unitCount: unitCount ?? this.unitCount,
      studentCount: studentCount ?? this.studentCount,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      ownerAdminId: ownerAdminId ?? this.ownerAdminId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    academicYear,
    targetGrade,
    unitCount,
    studentCount,
    isArchived,
    createdAt,
    ownerAdminId,
  ];
}

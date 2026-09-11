import 'package:equatable/equatable.dart';

enum AdjustmentType {
  bonus,
  minus;

  static AdjustmentType fromString(String? type) {
    if (type?.toLowerCase() == 'minus') return AdjustmentType.minus;
    return AdjustmentType.bonus;
  }

  String toValue() => name;
}

class EvaluationAdjustment extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String courseId;
  final int points; // e.g. +5 or -2
  final AdjustmentType type;
  final String reason;
  final DateTime date;
  final String addedBy;
  final String? teacherNotes;

  const EvaluationAdjustment({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.points,
    required this.type,
    required this.reason,
    required this.date,
    required this.addedBy,
    this.teacherNotes,
  });

  bool get isBonus => type == AdjustmentType.bonus;

  EvaluationAdjustment copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? courseId,
    int? points,
    AdjustmentType? type,
    String? reason,
    DateTime? date,
    String? addedBy,
    String? teacherNotes,
  }) {
    return EvaluationAdjustment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      courseId: courseId ?? this.courseId,
      points: points ?? this.points,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      date: date ?? this.date,
      addedBy: addedBy ?? this.addedBy,
      teacherNotes: teacherNotes ?? this.teacherNotes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    studentId,
    studentName,
    courseId,
    points,
    type,
    reason,
    date,
    addedBy,
    teacherNotes,
  ];
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/evaluation_adjustment.dart';

class EvaluationAdjustmentModel extends EvaluationAdjustment {
  const EvaluationAdjustmentModel({
    required super.id,
    required super.studentId,
    required super.studentName,
    required super.courseId,
    required super.points,
    required super.type,
    required super.reason,
    required super.date,
    required super.addedBy,
    super.teacherNotes,
  });

  factory EvaluationAdjustmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return EvaluationAdjustmentModel(
      id: doc.id,
      studentId: data['studentId']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? '',
      courseId: data['courseId']?.toString() ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      type: AdjustmentType.fromString(data['type']?.toString()),
      reason: data['reason']?.toString() ?? '',
      date:
          (data['date'] is Timestamp)
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now(),
      addedBy: data['addedBy']?.toString() ?? '',
      teacherNotes: data['teacherNotes']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'courseId': courseId,
      'points': points,
      'type': type.toValue(),
      'reason': reason,
      'date': Timestamp.fromDate(date),
      'addedBy': addedBy,
      'teacherNotes': teacherNotes,
    };
  }

  factory EvaluationAdjustmentModel.fromEntity(EvaluationAdjustment entity) {
    return EvaluationAdjustmentModel(
      id: entity.id,
      studentId: entity.studentId,
      studentName: entity.studentName,
      courseId: entity.courseId,
      points: entity.points,
      type: entity.type,
      reason: entity.reason,
      date: entity.date,
      addedBy: entity.addedBy,
      teacherNotes: entity.teacherNotes,
    );
  }
}

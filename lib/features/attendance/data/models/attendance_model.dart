import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/attendance_record.dart';

class AttendanceModel extends AttendanceRecord {
  const AttendanceModel({
    required super.id,
    required super.courseId,
    required super.sessionDate,
    required super.studentId,
    required super.studentName,
    required super.status,
    super.note,
    required super.recordedBy,
    required super.timestamp,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AttendanceModel(
      id: doc.id,
      courseId: data['courseId']?.toString() ?? '',
      sessionDate: data['sessionDate']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? '',
      status: AttendanceStatus.fromString(data['status']?.toString()),
      note: data['note']?.toString(),
      recordedBy: data['recordedBy']?.toString() ?? '',
      timestamp:
          (data['timestamp'] is Timestamp)
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'sessionDate': sessionDate,
      'studentId': studentId,
      'studentName': studentName,
      'status': status.toValue(),
      'note': note,
      'recordedBy': recordedBy,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory AttendanceModel.fromEntity(AttendanceRecord entity) {
    return AttendanceModel(
      id: entity.id,
      courseId: entity.courseId,
      sessionDate: entity.sessionDate,
      studentId: entity.studentId,
      studentName: entity.studentName,
      status: entity.status,
      note: entity.note,
      recordedBy: entity.recordedBy,
      timestamp: entity.timestamp,
    );
  }
}

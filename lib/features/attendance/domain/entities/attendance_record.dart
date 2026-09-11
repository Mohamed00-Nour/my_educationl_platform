import 'package:equatable/equatable.dart';

enum AttendanceStatus {
  present,
  absent,
  late;

  static AttendanceStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      case 'present':
      default:
        return AttendanceStatus.present;
    }
  }

  String toValue() => name;
}

class AttendanceRecord extends Equatable {
  final String id;
  final String courseId;
  final String sessionDate; // YYYY-MM-DD
  final String studentId;
  final String studentName;
  final AttendanceStatus status;
  final String? note;
  final String recordedBy;
  final DateTime timestamp;

  const AttendanceRecord({
    required this.id,
    required this.courseId,
    required this.sessionDate,
    required this.studentId,
    required this.studentName,
    required this.status,
    this.note,
    required this.recordedBy,
    required this.timestamp,
  });

  AttendanceRecord copyWith({
    String? id,
    String? courseId,
    String? sessionDate,
    String? studentId,
    String? studentName,
    AttendanceStatus? status,
    String? note,
    String? recordedBy,
    DateTime? timestamp,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      sessionDate: sessionDate ?? this.sessionDate,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      status: status ?? this.status,
      note: note ?? this.note,
      recordedBy: recordedBy ?? this.recordedBy,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    sessionDate,
    studentId,
    studentName,
    status,
    note,
    recordedBy,
    timestamp,
  ];
}

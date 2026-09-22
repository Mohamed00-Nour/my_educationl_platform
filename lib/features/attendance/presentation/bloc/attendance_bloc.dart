import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';

// EVENTS
abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();
  @override
  List<Object?> get props => [];
}

class LoadSessionAttendanceEvent extends AttendanceEvent {
  final String courseId;
  final String sessionDate;
  const LoadSessionAttendanceEvent({
    required this.courseId,
    required this.sessionDate,
  });
  @override
  List<Object?> get props => [courseId, sessionDate];
}

class ToggleStudentStatusEvent extends AttendanceEvent {
  final String studentId;
  final AttendanceStatus newStatus;
  const ToggleStudentStatusEvent({
    required this.studentId,
    required this.newStatus,
  });
  @override
  List<Object?> get props => [studentId, newStatus];
}

class MarkAllPresentEvent extends AttendanceEvent {}

class SaveAttendanceSessionEvent extends AttendanceEvent {}

class SaveStudentAttendanceEvent extends AttendanceEvent {
  final String studentId;
  const SaveStudentAttendanceEvent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

// STATES
abstract class AttendanceState extends Equatable {
  const AttendanceState();
  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoading extends AttendanceState {}

class AttendanceLoadedState extends AttendanceState {
  final String courseId;
  final String sessionDate;
  final List<AttendanceRecord> records;
  final Set<String> savedStudentIds;
  final Set<String> changedStudentIds;
  final bool isSaving;
  final String? saveError;
  final int? savedCount;

  const AttendanceLoadedState({
    required this.courseId,
    required this.sessionDate,
    required this.records,
    this.savedStudentIds = const {},
    this.changedStudentIds = const {},
    this.isSaving = false,
    this.saveError,
    this.savedCount,
  });

  AttendanceLoadedState copyWith({
    String? courseId,
    String? sessionDate,
    List<AttendanceRecord>? records,
    Set<String>? savedStudentIds,
    Set<String>? changedStudentIds,
    bool? isSaving,
    String? saveError,
    int? savedCount,
  }) {
    return AttendanceLoadedState(
      courseId: courseId ?? this.courseId,
      sessionDate: sessionDate ?? this.sessionDate,
      records: records ?? this.records,
      savedStudentIds: savedStudentIds ?? this.savedStudentIds,
      changedStudentIds: changedStudentIds ?? this.changedStudentIds,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError,
      savedCount: savedCount,
    );
  }

  @override
  List<Object?> get props => [
    courseId,
    sessionDate,
    records,
    savedStudentIds,
    changedStudentIds,
    isSaving,
    saveError,
    savedCount,
  ];
}

class AttendanceErrorState extends AttendanceState {
  final String message;
  const AttendanceErrorState(this.message);
  @override
  List<Object?> get props => [message];
}

// BLOC
class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceBloc(this._repository) : super(AttendanceInitial()) {
    on<LoadSessionAttendanceEvent>(_onLoadSession);
    on<ToggleStudentStatusEvent>(_onToggleStatus);
    on<MarkAllPresentEvent>(_onMarkAllPresent);
    on<SaveAttendanceSessionEvent>(_onSaveSession);
    on<SaveStudentAttendanceEvent>(_onSaveStudent);
  }

  Future<void> _onLoadSession(
    LoadSessionAttendanceEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(AttendanceLoading());
    try {
      final existing = await _repository.getAttendanceForSession(
        courseId: event.courseId,
        sessionDate: event.sessionDate,
      );

      final students = await _repository.getEnrolledStudents(
        courseId: event.courseId,
      );
      final existingByStudentId = {
        for (final record in existing) record.studentId: record,
      };
      final records = <AttendanceRecord>[];
      for (final student in students) {
        final studentId = student['id'] ?? '';
        if (studentId.isEmpty) continue;
        records.add(
          existingByStudentId.remove(studentId) ??
              AttendanceRecord(
                id: '',
                courseId: event.courseId,
                sessionDate: event.sessionDate,
                studentId: studentId,
                studentName: student['name'] ?? 'Student',
                status: AttendanceStatus.present,
                recordedBy: 'teacher',
                timestamp: DateTime.now(),
              ),
        );
      }
      records.addAll(existingByStudentId.values);
      records.sort(
        (a, b) => a.studentName.toLowerCase().compareTo(
          b.studentName.toLowerCase(),
        ),
      );

      emit(
        AttendanceLoadedState(
          courseId: event.courseId,
          sessionDate: event.sessionDate,
          records: records,
          savedStudentIds: existing.map((record) => record.studentId).toSet(),
        ),
      );
    } catch (e) {
      emit(AttendanceErrorState('Failed to load session attendance: $e'));
    }
  }

  void _onToggleStatus(
    ToggleStudentStatusEvent event,
    Emitter<AttendanceState> emit,
  ) {
    if (state is AttendanceLoadedState) {
      final current = state as AttendanceLoadedState;
      if (current.isSaving) return;
      final updated =
          current.records.map((r) {
            if (r.studentId == event.studentId) {
              return r.copyWith(
                status: event.newStatus,
                timestamp: DateTime.now(),
              );
            }
            return r;
          }).toList();

      emit(
        current.copyWith(
          records: updated,
          changedStudentIds: {...current.changedStudentIds, event.studentId},
        ),
      );
    }
  }

  void _onMarkAllPresent(
    MarkAllPresentEvent event,
    Emitter<AttendanceState> emit,
  ) {
    if (state is AttendanceLoadedState) {
      final current = state as AttendanceLoadedState;
      if (current.isSaving) return;
      final updated =
          current.records
              .map(
                (r) => r.copyWith(
                  status: AttendanceStatus.present,
                  timestamp: DateTime.now(),
                ),
              )
              .toList();
      emit(
        current.copyWith(
          records: updated,
          changedStudentIds: {
            ...current.changedStudentIds,
            ...current.records.map((record) => record.studentId),
          },
        ),
      );
    }
  }

  Future<void> _onSaveSession(
    SaveAttendanceSessionEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state is! AttendanceLoadedState) return;
    final current = state as AttendanceLoadedState;
    final changedRecords = current.records
        .where((record) => current.changedStudentIds.contains(record.studentId))
        .toList();
    await _saveRecords(current, changedRecords, emit);
  }

  Future<void> _onSaveStudent(
    SaveStudentAttendanceEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state is! AttendanceLoadedState) return;
    final current = state as AttendanceLoadedState;
    if (!current.changedStudentIds.contains(event.studentId)) return;
    final selected = current.records
        .where((record) => record.studentId == event.studentId)
        .toList();
    await _saveRecords(current, selected, emit);
  }

  Future<void> _saveRecords(
    AttendanceLoadedState current,
    List<AttendanceRecord> records,
    Emitter<AttendanceState> emit,
  ) async {
    if (current.isSaving || records.isEmpty) return;
    emit(current.copyWith(isSaving: true));
    try {
      await _repository.saveAttendanceBatch(records);
      final savedIds = records.map((record) => record.studentId).toSet();
      emit(
        current.copyWith(
          isSaving: false,
          savedStudentIds: {...current.savedStudentIds, ...savedIds},
          changedStudentIds: current.changedStudentIds.difference(savedIds),
          savedCount: records.length,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          isSaving: false,
          saveError: 'تعذر حفظ الحضور: $e',
        ),
      );
    }
  }
}

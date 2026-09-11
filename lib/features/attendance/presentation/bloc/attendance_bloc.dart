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
  final bool isSaving;

  const AttendanceLoadedState({
    required this.courseId,
    required this.sessionDate,
    required this.records,
    this.isSaving = false,
  });

  AttendanceLoadedState copyWith({
    String? courseId,
    String? sessionDate,
    List<AttendanceRecord>? records,
    bool? isSaving,
  }) {
    return AttendanceLoadedState(
      courseId: courseId ?? this.courseId,
      sessionDate: sessionDate ?? this.sessionDate,
      records: records ?? this.records,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props => [courseId, sessionDate, records, isSaving];
}

class AttendanceSaveSuccessState extends AttendanceState {
  final int count;
  const AttendanceSaveSuccessState(this.count);
  @override
  List<Object?> get props => [count];
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

      List<AttendanceRecord> records = existing;
      if (records.isEmpty) {
        final students = await _repository.getEnrolledStudents(
          courseId: event.courseId,
        );
        records =
            students
                .map(
                  (s) => AttendanceRecord(
                    id: '',
                    courseId: event.courseId,
                    sessionDate: event.sessionDate,
                    studentId: s['id'] ?? '',
                    studentName: s['name'] ?? 'Student',
                    status: AttendanceStatus.present,
                    recordedBy: 'teacher',
                    timestamp: DateTime.now(),
                  ),
                )
                .toList();
      }

      emit(
        AttendanceLoadedState(
          courseId: event.courseId,
          sessionDate: event.sessionDate,
          records: records,
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
      final updated =
          current.records.map((r) {
            if (r.studentId == event.studentId) {
              return r.copyWith(status: event.newStatus);
            }
            return r;
          }).toList();

      emit(current.copyWith(records: updated));
    }
  }

  void _onMarkAllPresent(
    MarkAllPresentEvent event,
    Emitter<AttendanceState> emit,
  ) {
    if (state is AttendanceLoadedState) {
      final current = state as AttendanceLoadedState;
      final updated =
          current.records
              .map((r) => r.copyWith(status: AttendanceStatus.present))
              .toList();
      emit(current.copyWith(records: updated));
    }
  }

  Future<void> _onSaveSession(
    SaveAttendanceSessionEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state is AttendanceLoadedState) {
      final current = state as AttendanceLoadedState;
      emit(current.copyWith(isSaving: true));

      try {
        await _repository.saveAttendanceBatch(current.records);
        emit(AttendanceSaveSuccessState(current.records.length));
      } catch (e) {
        emit(AttendanceErrorState('Failed to save attendance: $e'));
      }
    }
  }
}

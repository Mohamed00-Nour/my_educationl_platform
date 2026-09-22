import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/attendance/domain/entities/attendance_record.dart';
import 'package:instructor/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:instructor/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _AttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  setUpAll(() => registerFallbackValue(<AttendanceRecord>[]));

  test('loading a partial session retains unmarked classmates', () async {
    final repository = _AttendanceRepository();
    final recorded = AttendanceRecord(
      id: 'saved-a',
      courseId: 'course',
      sessionDate: '2026-09-22',
      studentId: 'a',
      studentName: 'Ahmed',
      status: AttendanceStatus.present,
      recordedBy: 'teacher',
      timestamp: DateTime.utc(2026, 9, 22),
    );
    when(
      () => repository.getAttendanceForSession(
        courseId: 'course',
        sessionDate: '2026-09-22',
      ),
    ).thenAnswer((_) async => [recorded]);
    when(
      () => repository.getEnrolledStudents(courseId: 'course'),
    ).thenAnswer(
      (_) async => [
        {'id': 'a', 'name': 'Ahmed'},
        {'id': 'b', 'name': 'Basma'},
      ],
    );
    when(() => repository.saveAttendanceBatch(any())).thenAnswer((_) async {});

    final bloc = AttendanceBloc(repository);
    final loadedFuture = bloc.stream.firstWhere(
      (state) => state is AttendanceLoadedState,
    );
    bloc.add(
      const LoadSessionAttendanceEvent(
        courseId: 'course',
        sessionDate: '2026-09-22',
      ),
    );
    final loaded = await loadedFuture as AttendanceLoadedState;

    expect(loaded.records.map((record) => record.studentId), ['a', 'b']);
    expect(loaded.savedStudentIds, {'a'});
    expect(loaded.changedStudentIds, isEmpty);

    final changedAhmedFuture = bloc.stream.firstWhere(
      (state) =>
          state is AttendanceLoadedState &&
          state.changedStudentIds.contains('a'),
    );
    bloc.add(
      const ToggleStudentStatusEvent(
        studentId: 'a',
        newStatus: AttendanceStatus.late,
      ),
    );
    await changedAhmedFuture;

    final changedFuture = bloc.stream.firstWhere(
      (state) =>
          state is AttendanceLoadedState &&
          state.changedStudentIds.contains('b'),
    );
    bloc.add(
      const ToggleStudentStatusEvent(
        studentId: 'b',
        newStatus: AttendanceStatus.absent,
      ),
    );
    await changedFuture;

    final savedFuture = bloc.stream.firstWhere(
      (state) =>
          state is AttendanceLoadedState && state.savedCount == 1,
    );
    bloc.add(const SaveStudentAttendanceEvent('b'));
    final saved = await savedFuture as AttendanceLoadedState;

    final written = verify(
      () => repository.saveAttendanceBatch(captureAny()),
    ).captured.single as List<AttendanceRecord>;
    expect(written, hasLength(1));
    expect(written.single.studentId, 'b');
    expect(written.single.status, AttendanceStatus.absent);
    expect(saved.savedStudentIds, {'a', 'b'});
    expect(saved.changedStudentIds, {'a'});

    final savedRemainingFuture = bloc.stream.firstWhere(
      (state) =>
          state is AttendanceLoadedState &&
          state.savedCount == 1 &&
          state.changedStudentIds.isEmpty,
    );
    bloc.add(SaveAttendanceSessionEvent());
    await savedRemainingFuture;
    final remainingWritten = verify(
      () => repository.saveAttendanceBatch(captureAny()),
    ).captured.single as List<AttendanceRecord>;
    expect(remainingWritten, hasLength(1));
    expect(remainingWritten.single.studentId, 'a');
    expect(remainingWritten.single.status, AttendanceStatus.late);

    await bloc.close();
  });
}

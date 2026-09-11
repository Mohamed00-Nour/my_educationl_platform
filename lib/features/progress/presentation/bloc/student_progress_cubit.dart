import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/student_progress_summary.dart';
import '../../domain/repositories/progress_repository.dart';

abstract class StudentProgressState extends Equatable {
  const StudentProgressState();
  @override
  List<Object?> get props => [];
}

class StudentProgressInitial extends StudentProgressState {}

class StudentProgressLoading extends StudentProgressState {}

class StudentProgressLoaded extends StudentProgressState {
  final StudentProgressSummary summary;
  const StudentProgressLoaded(this.summary);
  @override
  List<Object?> get props => [summary];
}

class StudentProgressError extends StudentProgressState {
  final String message;
  const StudentProgressError(this.message);
  @override
  List<Object?> get props => [message];
}

class StudentProgressCubit extends Cubit<StudentProgressState> {
  final ProgressRepository _repository;

  StudentProgressCubit(this._repository) : super(StudentProgressInitial());

  Future<void> loadSummary({
    required String studentId,
    required String studentName,
    required String courseId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    emit(StudentProgressLoading());
    try {
      final summary = await _repository.getStudentProgressSummary(
        studentId: studentId,
        studentName: studentName,
        courseId: courseId,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: forceRefresh,
      );
      emit(StudentProgressLoaded(summary));
    } catch (e) {
      emit(StudentProgressError('Failed to load progress summary: $e'));
    }
  }
}

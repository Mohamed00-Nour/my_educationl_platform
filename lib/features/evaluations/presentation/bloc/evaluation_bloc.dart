import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/evaluation_adjustment.dart';
import '../../domain/repositories/evaluation_repository.dart';

// EVENTS
abstract class EvaluationEvent extends Equatable {
  const EvaluationEvent();
  @override
  List<Object?> get props => [];
}

class LoadEvaluationsEvent extends EvaluationEvent {
  final String courseId;
  final String? studentId;
  const LoadEvaluationsEvent({required this.courseId, this.studentId});
  @override
  List<Object?> get props => [courseId, studentId];
}

class AddAdjustmentEvent extends EvaluationEvent {
  final EvaluationAdjustment adjustment;
  const AddAdjustmentEvent(this.adjustment);
  @override
  List<Object?> get props => [adjustment];
}

class DeleteAdjustmentEvent extends EvaluationEvent {
  final String id;
  const DeleteAdjustmentEvent(this.id);
  @override
  List<Object?> get props => [id];
}

// STATES
abstract class EvaluationState extends Equatable {
  const EvaluationState();
  @override
  List<Object?> get props => [];
}

class EvaluationInitial extends EvaluationState {}

class EvaluationLoading extends EvaluationState {}

class EvaluationLoadedState extends EvaluationState {
  final List<EvaluationAdjustment> adjustments;
  final int totalBonusPoints;
  final int totalMinusPoints;
  final int netAdjustmentPoints;

  const EvaluationLoadedState({
    required this.adjustments,
    required this.totalBonusPoints,
    required this.totalMinusPoints,
    required this.netAdjustmentPoints,
  });

  @override
  List<Object?> get props => [
    adjustments,
    totalBonusPoints,
    totalMinusPoints,
    netAdjustmentPoints,
  ];
}

class EvaluationErrorState extends EvaluationState {
  final String message;
  const EvaluationErrorState(this.message);
  @override
  List<Object?> get props => [message];
}

// BLOC
class EvaluationBloc extends Bloc<EvaluationEvent, EvaluationState> {
  final EvaluationRepository _repository;

  EvaluationBloc(this._repository) : super(EvaluationInitial()) {
    on<LoadEvaluationsEvent>(_onLoadEvaluations);
    on<AddAdjustmentEvent>(_onAddAdjustment);
    on<DeleteAdjustmentEvent>(_onDeleteAdjustment);
  }

  Future<void> _onLoadEvaluations(
    LoadEvaluationsEvent event,
    Emitter<EvaluationState> emit,
  ) async {
    emit(EvaluationLoading());
    try {
      List<EvaluationAdjustment> items;
      if (event.studentId != null) {
        items = await _repository.getAdjustmentsForStudent(
          studentId: event.studentId!,
          courseId: event.courseId,
        );
      } else {
        items = await _repository.getAdjustmentsForCourse(event.courseId);
      }

      int bonus = 0;
      int minus = 0;
      for (final a in items) {
        if (a.isBonus) {
          bonus += a.points.abs();
        } else {
          minus += a.points.abs();
        }
      }

      emit(
        EvaluationLoadedState(
          adjustments: items,
          totalBonusPoints: bonus,
          totalMinusPoints: minus,
          netAdjustmentPoints: bonus - minus,
        ),
      );
    } catch (e) {
      emit(EvaluationErrorState('Failed to load adjustments: $e'));
    }
  }

  Future<void> _onAddAdjustment(
    AddAdjustmentEvent event,
    Emitter<EvaluationState> emit,
  ) async {
    try {
      await _repository.addAdjustment(event.adjustment);
      add(
        LoadEvaluationsEvent(
          courseId: event.adjustment.courseId,
          studentId: event.adjustment.studentId,
        ),
      );
    } catch (e) {
      emit(EvaluationErrorState('Failed to add adjustment: $e'));
    }
  }

  Future<void> _onDeleteAdjustment(
    DeleteAdjustmentEvent event,
    Emitter<EvaluationState> emit,
  ) async {
    try {
      await _repository.deleteAdjustment(event.id);
    } catch (e) {
      emit(EvaluationErrorState('Failed to delete adjustment: $e'));
    }
  }
}

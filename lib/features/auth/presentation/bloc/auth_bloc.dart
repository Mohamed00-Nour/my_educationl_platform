import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

// EVENTS
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class SignInRequested extends AuthEvent {
  final String email;
  final String password;
  const SignInRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  final UserRole role;
  final StudentGrade? grade;
  final String? teacherCode;
  final String? enrolledCourseId;

  const SignUpRequested({
    required this.email,
    required this.password,
    required this.displayName,
    required this.role,
    this.grade,
    this.teacherCode,
    this.enrolledCourseId,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    displayName,
    role,
    grade,
    teacherCode,
    enrolledCourseId,
  ];
}

class SignOutRequested extends AuthEvent {}

class RoleSwitchedForDemo extends AuthEvent {
  final UserRole newRole;
  const RoleSwitchedForDemo(this.newRole);
  @override
  List<Object?> get props => [newRole];
}

// STATES
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final UserEntity user;
  const Authenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthErrorState extends AuthState {
  final String message;
  const AuthErrorState(this.message);
  @override
  List<Object?> get props => [message];
}

// BLOC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final dynamic _validateJoinCodeUseCase;
  final dynamic _manageJoinCodeUseCase;

  AuthBloc(
    this._authRepository, {
    dynamic validateJoinCodeUseCase,
    dynamic manageJoinCodeUseCase,
  }) : _validateJoinCodeUseCase = validateJoinCodeUseCase,
       _manageJoinCodeUseCase = manageJoinCodeUseCase,
       super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<SignInRequested>(_onSignInRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<RoleSwitchedForDemo>(_onRoleSwitchedForDemo);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      emit(Authenticated(user));
    } on Failure catch (f) {
      _logFailure('sign-in', f);
      emit(AuthErrorState(f.message));
    } catch (e) {
      _logUnexpectedError('sign-in', e);
      emit(AuthErrorState('An unexpected error occurred. Please try again.'));
    }
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      String? matchedAdminId;

      // Validate Teacher Join Code for student registrations
      if (event.role == UserRole.student) {
        final code = event.teacherCode?.trim();
        if (code == null || code.isEmpty) {
          emit(
            const AuthErrorState(
              'يرجى إدخال كود المعلم / المشرف لإتمام إنشاء حساب الطالب.',
            ),
          );
          return;
        }

        if (_validateJoinCodeUseCase != null) {
          final joinCodeEntity = await _validateJoinCodeUseCase.call(code);
          matchedAdminId = joinCodeEntity.adminId;
        }
      }

      final enrolledCourseIds = [
        if (event.enrolledCourseId != null &&
            event.enrolledCourseId!.isNotEmpty)
          event.enrolledCourseId!,
      ];

      final user = await _authRepository.signUpWithEmailAndPassword(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
        role: event.role,
        grade: event.grade,
        ownerAdminId: matchedAdminId,
        enrolledCourseIds: enrolledCourseIds,
      );

      // Auto-generate initial Join Code for newly registered Admins
      if (user.role.isAdmin && _manageJoinCodeUseCase != null) {
        try {
          await _manageJoinCodeUseCase.generateOrRegenerate(
            adminId: user.id,
            adminName: user.displayName,
            createdBy: user.id,
          );
        } catch (_) {
          // Non-blocking for admin sign up; code can be generated in dashboard
        }
      }

      emit(Authenticated(user));
    } on Failure catch (f) {
      _logFailure('sign-up', f);
      emit(AuthErrorState(f.message));
    } catch (e) {
      _logUnexpectedError('sign-up', e);
      emit(AuthErrorState('Account registration failed: $e'));
    }
  }

  void _logFailure(String operation, Failure failure) {
    if (!kDebugMode) return;
    debugPrint(
      '❌ [AuthBloc][$operation][${failure.code ?? 'no-code'}] '
      '${failure.message}',
    );
  }

  void _logUnexpectedError(String operation, Object error) {
    if (!kDebugMode) return;
    debugPrint('❌ [AuthBloc][$operation][unexpected] $error');
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(Unauthenticated());
    }
  }

  void _onRoleSwitchedForDemo(
    RoleSwitchedForDemo event,
    Emitter<AuthState> emit,
  ) {
    if (state is Authenticated) {
      final current = (state as Authenticated).user;
      final updated = current.copyWith(role: event.newRole);
      emit(Authenticated(updated));
    }
  }
}

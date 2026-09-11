import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'A server communication error occurred. Please try again.',
    String? code,
  ]) : super(code: code);
}

class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'Authentication failed. Please check your credentials.',
    String? code,
  ]) : super(code: code);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message =
        'No internet connection detected. Please check your network.',
    String? code,
  ]) : super(code: code);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([
    super.message = 'Requested resource was not found.',
    String? code,
  ]) : super(code: code);
}

class CacheFailure extends Failure {
  const CacheFailure([
    super.message = 'Local cache retrieval failed.',
    String? code,
  ]) : super(code: code);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'You do not have permission to perform this action.',
    String? code,
  ]) : super(code: code);
}

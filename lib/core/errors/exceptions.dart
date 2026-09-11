class ServerException implements Exception {
  final String message;
  final String? code;
  const ServerException([
    this.message = 'Server exception occurred',
    this.code,
  ]);

  @override
  String toString() => 'ServerException: $message ($code)';
}

class AuthException implements Exception {
  final String message;
  final String? code;
  const AuthException([
    this.message = 'Authentication exception occurred',
    this.code,
  ]);

  @override
  String toString() => 'AuthException: $message ($code)';
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Local cache exception occurred']);

  @override
  String toString() => 'CacheException: $message';
}

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Unauthorized action']);

  @override
  String toString() => 'UnauthorizedException: $message';
}

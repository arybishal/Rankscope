/// Infrastructure and low-level exceptions.
class DatabaseException implements Exception {
  final String message;
  final dynamic cause;
  const DatabaseException(this.message, [this.cause]);

  @override
  String toString() =>
      'DatabaseException: $message ${cause != null ? '($cause)' : ''}';
}

class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  const NetworkException(this.message, {this.statusCode});

  @override
  String toString() => 'NetworkException: $message (status: $statusCode)';
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

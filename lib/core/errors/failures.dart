/// Domain-level failure representations for robust error handling.
abstract class Failure {
  final String message;
  final String? code;
  const Failure(this.message, {this.code});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (code: $code)' : ''}';
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure(super.message, {super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

class SecurityFailure extends Failure {
  const SecurityFailure(super.message, {super.code});
}

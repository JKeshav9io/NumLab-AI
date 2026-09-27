import 'package:equatable/equatable.dart';

/// Sealed domain failure hierarchy for NumLab AI.
/// Every remote exception and network failure is mapped to one of these types
/// before reaching BLoCs or presentation layers.
sealed class Failure extends Equatable {
  const Failure({
    required this.message,
    this.code,
  });

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

/// Represents socket timeouts, loss of internet connectivity, or host unreachable errors.
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code = 'NETWORK_ERROR',
  });
}

/// Represents 5xx errors, internal server errors, unhandled exceptions, or database errors.
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code = 'INTERNAL_ERROR',
    this.statusCode,
  });

  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

/// Represents 401/403 authentication and authorization failures
/// (invalid credentials, expired tokens, revoked tokens, unauthorized access).
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code = 'UNAUTHORIZED',
  });
}

/// Represents 400 Joi validation failures with structured field errors.
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.fieldErrors = const [],
  });

  final List<FieldError> fieldErrors;

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

/// Represents granular field validation errors returned in backend `error.details.fields`.
class FieldError extends Equatable {
  const FieldError({
    required this.field,
    required this.message,
  });

  factory FieldError.fromJson(Map<String, dynamic> json) {
    return FieldError(
      field: json['field'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  final String field;
  final String message;

  @override
  List<Object?> get props => [field, message];
}

/// Represents 429 rate limit exceeded errors with optional retry cooldown.
class RateLimitFailure extends Failure {
  const RateLimitFailure({
    required super.message,
    super.code = 'RATE_LIMIT_EXCEEDED',
    this.retryAfterSeconds,
  });

  final int? retryAfterSeconds;

  @override
  List<Object?> get props => [message, code, retryAfterSeconds];
}

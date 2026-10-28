import 'package:dio/dio.dart';
import 'package:numlab_frontend/core/error/failures.dart';

/// Translates raw exceptions (such as [DioException] or unexpected errors)
/// into strongly typed [Failure] instances aligned with NumLab backend contracts.
Failure mapExceptionToFailure(Object exception, [StackTrace? stackTrace]) {
  if (exception is DioException) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkFailure(
          message:
              'Unable to connect to NumLab server: the connection timed out. Please try again.',
          code: 'REQUEST_TIMEOUT',
        );

      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkFailure(
          message: 'The request timed out. Please try again.',
          code: 'REQUEST_TIMEOUT',
        );

      case DioExceptionType.connectionError:
        return const NetworkFailure(
          message:
              'Unable to connect to NumLab server. Please check your connection.',
        );

      case DioExceptionType.badResponse:
        final response = exception.response;
        // The route limiter can return a plain-text 429 instead of an envelope.
        if (response?.statusCode == 429) {
          final body = response!.data;
          final error = body is Map ? body['error'] : null;
          return RateLimitFailure(
            message: error is Map && error['message'] is String
                ? error['message'] as String
                : 'Too many requests. Please wait before trying again.',
            code: error is Map && error['code'] is String
                ? error['code'] as String
                : 'RATE_LIMIT_EXCEEDED',
            retryAfterSeconds: _retryAfterSeconds(
              response,
              error is Map ? error['details'] : null,
            ),
          );
        }
        if (response != null && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          final errorObj = data['error'];

          if (errorObj is Map<String, dynamic>) {
            final code = errorObj['code'] as String? ?? 'INTERNAL_ERROR';
            final message =
                errorObj['message'] as String? ?? 'An error occurred';
            final details = errorObj['details'];

            // 1. Rate Limiting (429)
            if (code == 'RATE_LIMIT_EXCEEDED' || response.statusCode == 429) {
              return RateLimitFailure(
                message: message,
                code: code,
                retryAfterSeconds: _retryAfterSeconds(response, details),
              );
            }

            // 2. Validation Errors (400)
            if (code == 'VALIDATION_ERROR') {
              final fieldErrors = <FieldError>[];
              // The report UUID validator uses details.details: [string],
              // unlike solver field maps. Retain messages without inventing
              // field names, and ignore malformed fields rather than casting.
              final fieldsList = details is Map<String, dynamic>
                  ? details['fields'] ?? details['errors'] ?? details['details']
                  : details;
              if (fieldsList is List) {
                for (final item in fieldsList) {
                  if (item is Map<String, dynamic> &&
                      (item['field'] == null || item['field'] is String) &&
                      (item['message'] == null || item['message'] is String)) {
                    fieldErrors.add(FieldError.fromJson(item));
                  } else if (item is String) {
                    fieldErrors.add(FieldError(field: '', message: item));
                  }
                }
              }
              return ValidationFailure(
                message: message,
                code: code,
                fieldErrors: fieldErrors,
              );
            }

            // 3. Auth Failures (401 / 403)
            if (response.statusCode == 401 ||
                response.statusCode == 403 ||
                code == 'INVALID_CREDENTIALS' ||
                code == 'TOKEN_EXPIRED' ||
                code == 'TOKEN_REVOKED' ||
                code == 'INVALID_TOKEN' ||
                code == 'UNAUTHORIZED' ||
                code == 'FORBIDDEN') {
              return AuthFailure(
                message: message,
                code: code,
              );
            }

            // 4. Default Server Failure with backend code and friendly message presentation
            return ServerFailure(
              message: _formatFriendlySolverMessage(code, message),
              code: code,
              statusCode: response.statusCode,
            );
          }
        }

        return ServerFailure(
          message:
              'Server responded with error status: ${response?.statusCode}',
          statusCode: response?.statusCode,
        );

      case DioExceptionType.cancel:
        return const NetworkFailure(message: 'Request was cancelled.');

      case DioExceptionType.badCertificate:
        return const NetworkFailure(message: 'Invalid server SSL certificate.');

      case DioExceptionType.unknown:
        return NetworkFailure(
          message: exception.message ?? 'An unexpected network error occurred.',
        );
    }
  }

  return ServerFailure(
    message: exception.toString(),
  );
}

int? _retryAfterSeconds(Response<dynamic> response, Object? details) {
  final bodySeconds = _nonNegativeSeconds(
    details is Map ? details['retryAfterSeconds'] : null,
  );
  final headerSeconds = _nonNegativeSeconds(
    response.headers['retry-after']?.firstOrNull,
  );
  if (bodySeconds == null) return headerSeconds;
  if (headerSeconds == null) return bodySeconds;
  // Respect both supplied constraints if they differ.
  return bodySeconds > headerSeconds ? bodySeconds : headerSeconds;
}

int? _nonNegativeSeconds(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is String && RegExp(r'^\d+$').hasMatch(value.trim())) {
    return int.tryParse(value.trim());
  }
  return null;
}

String _formatFriendlySolverMessage(String code, String rawMessage) {
  if (code == 'SOLVER_PRECONDITION_FAILED') {
    if (rawMessage.isEmpty || rawMessage == code) {
      return 'Solver precondition failed. Please check that initial bounds or inputs satisfy the algorithm requirements.';
    }
    return rawMessage;
  }
  if (code == 'SINGULAR_MATRIX' || code == 'SOLVER_SINGULAR_MATRIX') {
    return 'The system matrix is singular (determinant is zero) and has no unique solution.';
  }
  if (code == 'SOLVER_MAX_ITERATIONS_EXCEEDED') {
    return 'Maximum iterations exceeded without reaching convergence tolerance.';
  }
  if (code == 'SOLVER_DIVERGENCE' || code == 'SOLVER_DIVERGED') {
    return 'Calculation diverged. Try adjusting initial guesses or step size.';
  }
  if (code == 'ZERO_DIVISION' || code == 'DIVISION_BY_ZERO') {
    return 'Division by zero occurred during calculation.';
  }
  return rawMessage;
}

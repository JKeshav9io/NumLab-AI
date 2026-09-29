import 'package:dio/dio.dart';
import 'package:numlab_frontend/core/error/failures.dart';

/// Translates raw exceptions (such as [DioException] or unexpected errors)
/// into strongly typed [Failure] instances aligned with NumLab backend contracts.
Failure mapExceptionToFailure(Object exception, [StackTrace? stackTrace]) {
  if (exception is DioException) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.transformTimeout:
        return const NetworkFailure(
          message:
              'Unable to connect to NumLab server. Please check your connection.',
        );

      case DioExceptionType.badResponse:
        final response = exception.response;
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
              );
            }

            // 2. Validation Errors (400)
            if (code == 'VALIDATION_ERROR') {
              final fieldErrors = <FieldError>[];
              if (details is Map<String, dynamic>) {
                final fieldsList = details['fields'] ?? details['errors'];
                if (fieldsList is List) {
                  for (final item in fieldsList) {
                    if (item is Map<String, dynamic>) {
                      fieldErrors.add(FieldError.fromJson(item));
                    }
                  }
                }
              } else if (details is List) {
                for (final item in details) {
                  if (item is Map<String, dynamic>) {
                    fieldErrors.add(FieldError.fromJson(item));
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

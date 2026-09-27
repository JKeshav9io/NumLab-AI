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
            if (code == 'VALIDATION_ERROR' && details is Map<String, dynamic>) {
              final fieldsList = details['fields'];
              final fieldErrors = <FieldError>[];
              if (fieldsList is List) {
                for (final item in fieldsList) {
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

            // 4. Default Server Failure with backend code
            return ServerFailure(
              message: message,
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

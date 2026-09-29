import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Request and Response logger interceptor gated strictly to debug builds.
/// Automatically redacts sensitive fields (passwords, JWTs, refresh tokens, Authorization headers)
/// to prevent leaking credentials in development logs, and prints zero logs in release mode.
class DebugLoggingInterceptor extends Interceptor {
  DebugLoggingInterceptor({Logger? logger})
    : _logger =
          logger ??
          Logger(
            printer: PrettyPrinter(
              methodCount: 0,
              errorMethodCount: 5,
            ),
          );

  final Logger _logger;

  static const Set<String> _sensitiveKeys = {
    'password',
    'password_confirmation',
    'token',
    'accesstoken',
    'refreshtoken',
    'access_token',
    'refresh_token',
    'secret',
    'jwt',
    'authorization',
    'apikey',
    'api_key',
    'key',
  };

  /// Recursively redacts sensitive keys from Map and List structures.
  static dynamic redactData(dynamic data) {
    if (data is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in data.entries) {
        final keyStr = entry.key.toString();
        final normalizedKey = keyStr.toLowerCase().replaceAll(
          RegExp('[^a-z0-9]'),
          '',
        );

        if (entry.value is Map || entry.value is List) {
          sanitized[keyStr] = redactData(entry.value);
        } else if (_sensitiveKeys.contains(normalizedKey) ||
            normalizedKey.contains('password') ||
            normalizedKey.contains('token') ||
            normalizedKey.contains('secret') ||
            normalizedKey.contains('key') ||
            normalizedKey.contains('auth')) {
          sanitized[keyStr] = '[REDACTED]';
        } else {
          sanitized[keyStr] = entry.value;
        }
      }
      return sanitized;
    }

    if (data is List) {
      return data.map(redactData).toList();
    }

    return data;
  }

  /// Redacts sensitive headers such as Authorization and Cookies.
  static Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};
    for (final entry in headers.entries) {
      final keyLower = entry.key.toLowerCase();
      if (keyLower == 'authorization' ||
          keyLower == 'cookie' ||
          keyLower.contains('auth') ||
          keyLower.contains('token') ||
          keyLower.contains('secret')) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final safeHeaders = redactHeaders(options.headers);
      final safeData = redactData(options.data);
      _logger.d(
        '--> ${options.method} ${options.uri}\nHeaders: $safeHeaders\nData: $safeData',
      );
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      final safeData = redactData(response.data);
      _logger.i(
        '<-- ${response.statusCode} ${response.requestOptions.uri}\nData: $safeData',
      );
    }
    super.onResponse(response, handler);
  }

  /// Extracts error code from backend response payload if present.
  static String? extractErrorCode(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = error['code'];
        if (code is String && code.trim().isNotEmpty) {
          return code.trim();
        }
      }
      if (error is String &&
          error.trim().isNotEmpty &&
          !error.contains(' ') &&
          !error.startsWith('<')) {
        return error.trim();
      }
      if (data['code'] is String && (data['code'] as String).trim().isNotEmpty) {
        return (data['code'] as String).trim();
      }
    }
    return null;
  }

  /// Extracts human-readable error message from backend response payload if present.
  static String? extractErrorMessage(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final msg = error['message'];
        if (msg is String && msg.trim().isNotEmpty) {
          return msg.trim();
        }
      }
      if (error is String &&
          error.trim().isNotEmpty &&
          !error.trimLeft().startsWith('<')) {
        return error.trim();
      }
      if (data['message'] is String &&
          (data['message'] as String).trim().isNotEmpty) {
        return (data['message'] as String).trim();
      }
    } else if (data is String &&
        data.trim().isNotEmpty &&
        !data.trimLeft().startsWith('<')) {
      final trimmed = data.trim();
      return trimmed.length > 300
          ? '${trimmed.substring(0, 300)}...'
          : trimmed;
    }
    return null;
  }

  /// Extracts error details from backend response payload if present.
  static dynamic extractErrorDetails(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error.containsKey('details')) {
        return error['details'];
      }
      if (data.containsKey('details')) {
        return data['details'];
      }
    }
    return null;
  }

  static bool _isUsefulDetails(dynamic details) {
    if (details == null) return false;
    if (details is Map) return details.isNotEmpty;
    if (details is Iterable) return details.isNotEmpty;
    if (details is String) return details.trim().isNotEmpty;
    return true;
  }

  static String _formatEndpoint(RequestOptions options) {
    final uri = options.uri;
    final path = uri.path.isNotEmpty ? uri.path : options.path;
    final displayPath = path.isNotEmpty ? path : '/';
    if (uri.hasQuery && uri.query.isNotEmpty && !displayPath.contains('?')) {
      return '$displayPath?${uri.query}';
    }
    return displayPath;
  }

  /// Formats a concise, actionable terminal log for HTTP 400 responses
  /// without printing Dio's verbose generic boilerplate explanations.
  static String formatBadRequestLog(DioException err) {
    final responseData = err.response?.data;
    final code = extractErrorCode(responseData) ?? 'BAD_REQUEST';
    final rawMessage = extractErrorMessage(responseData);
    final fallbackMessage =
        (err.response?.statusMessage != null &&
            err.response!.statusMessage!.trim().isNotEmpty)
            ? err.response!.statusMessage!.trim()
            : 'Bad Request';
    final message = rawMessage ?? fallbackMessage;

    final method =
        err.requestOptions.method.isNotEmpty
            ? err.requestOptions.method
            : 'POST';
    final endpoint = _formatEndpoint(err.requestOptions);

    final buffer = StringBuffer('⚠️ [400 $code] $method $endpoint');
    if (message.isNotEmpty) {
      buffer.write('\n$message');
    }

    final rawDetails = extractErrorDetails(responseData);
    final sanitizedDetails = redactData(rawDetails);
    if (_isUsefulDetails(sanitizedDetails)) {
      buffer.write('\ndetails: $sanitizedDetails');
    }

    return buffer.toString();
  }

  /// Determines whether the error is an expected domain/solver error (4xx validation, precondition, singular matrix).
  static bool isExpectedDomainError(DioException err) {
    final status = err.response?.statusCode;
    if (status != null && (status == 400 || status == 422)) {
      final code = extractErrorCode(err.response?.data);
      if (code != null &&
          (code.startsWith('SOLVER_') ||
              code.startsWith('VALIDATION_') ||
              code == 'SINGULAR_MATRIX' ||
              code == 'MATH_ERROR' ||
              code == 'EVAL_FAILED' ||
              code == 'INVALID_EXPRESSION' ||
              code == 'INVALID_JSON')) {
        return true;
      }
    }
    return false;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final statusCode = err.response?.statusCode;
      if (statusCode == 400) {
        _logger.w(formatBadRequestLog(err));
      } else if (isExpectedDomainError(err)) {
        final code = extractErrorCode(err.response?.data) ?? 'VALIDATION_ERROR';
        final status = err.response?.statusCode;
        final msg = extractErrorMessage(err.response?.data) ??
            err.response?.statusMessage ??
            'Validation Error';
        _logger.w(
          '<-- [$status $code] ${err.requestOptions.method} ${_formatEndpoint(err.requestOptions)} - $msg',
        );
      } else {
        final safeResponseData = redactData(err.response?.data);
        _logger.e(
          '<-- ERROR [${err.response?.statusCode}] ${err.requestOptions.uri}\nMessage: ${err.message}\nResponse: $safeResponseData',
          error: err.error,
          stackTrace: err.stackTrace,
        );
      }
    }
    super.onError(err, handler);
  }
}

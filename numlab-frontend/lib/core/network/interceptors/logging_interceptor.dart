import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Request and Response logger interceptor gated strictly to debug builds.
/// In release mode, zero logs are printed to safeguard sensitive payloads and tokens.
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

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.d(
        '--> ${options.method} ${options.uri}\nHeaders: ${options.headers}\nData: ${options.data}',
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
      _logger.i(
        '<-- ${response.statusCode} ${response.requestOptions.uri}\nData: ${response.data}',
      );
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.e(
        '<-- ERROR [${err.response?.statusCode}] ${err.requestOptions.uri}\nMessage: ${err.message}\nResponse: ${err.response?.data}',
        error: err.error,
        stackTrace: err.stackTrace,
      );
    }
    super.onError(err, handler);
  }
}

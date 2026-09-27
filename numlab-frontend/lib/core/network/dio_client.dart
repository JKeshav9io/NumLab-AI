import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/core/network/interceptors/auth_interceptor.dart';
import 'package:numlab_frontend/core/network/interceptors/logging_interceptor.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';

/// Factory and configuration builder for the application [Dio] HTTP client.
abstract final class DioClient {
  static Dio create({
    required SecureStorageService secureStorageService,
    String? baseUrl,
    Dio? refreshDio,
    void Function()? onSessionRevoked,
  }) {
    final effectiveBaseUrl = baseUrl ?? ApiConstants.defaultBaseUrl;

    // Unintercepted Dio instance for refresh calls to avoid interceptor recursion/deadlock
    final internalRefreshDio =
        refreshDio ??
        Dio(
          BaseOptions(
            baseUrl: effectiveBaseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            sendTimeout: ApiConstants.sendTimeout,
            headers: const <String, dynamic>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    final dio = Dio(
      BaseOptions(
        baseUrl: effectiveBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: const <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 1. Auth Interceptor (Queued for token refresh in Phase 1)
    dio.interceptors.add(
      AuthInterceptor(
        secureStorageService: secureStorageService,
        refreshDio: internalRefreshDio,
        retryDio: dio,
        onSessionRevoked: onSessionRevoked,
      ),
    );

    // 2. Logging Interceptor (debug builds only)
    if (kDebugMode) {
      dio.interceptors.add(DebugLoggingInterceptor());
    }

    return dio;
  }
}

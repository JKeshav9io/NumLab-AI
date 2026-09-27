import 'dart:async';

import 'package:dio/dio.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';

/// Interceptor for Bearer token injection, silent token refresh, and request retry queuing.
///
/// Lifecycle:
/// 1. [onRequest]: Automatically injects `Authorization: Bearer <accessToken>` when a token
///    is present in [SecureStorageService], unless explicitly provided or targeting `/auth/refresh`.
/// 2. [onError]: Intercepts `401 TOKEN_EXPIRED` errors. Queues incoming requests, performs
///    single-use token rotation via `/auth/refresh`, persists rotated tokens, and retries
///    the original request once.
/// 3. Concurrency Protection: Ensures simultaneous expired requests share a single refresh
///    operation rather than sending concurrent refresh calls.
/// 4. Failure Protection: If refresh fails (`TOKEN_REVOKED`, `INVALID_TOKEN`, missing refresh token),
///    clears credentials from [SecureStorageService] and forwards the failure without recursion.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required SecureStorageService secureStorageService,
    Dio? refreshDio,
    Dio? retryDio,
    Future<TokenModel> Function(String refreshToken)? refreshHandler,
    void Function()? onSessionRevoked,
  }) : _secureStorageService = secureStorageService,
       _refreshDio = refreshDio,
       _retryDio = retryDio,
       _refreshHandler = refreshHandler,
       _onSessionRevoked = onSessionRevoked;

  final SecureStorageService _secureStorageService;
  final Dio? _refreshDio;
  final Dio? _retryDio;
  final Future<TokenModel> Function(String refreshToken)? _refreshHandler;
  final void Function()? _onSessionRevoked;

  Completer<bool>? _refreshCompleter;

  /// Request extra key used to track retry attempts and prevent infinite loops.
  static const String retryCountExtraKey = 'numlab_auth_retry_count';

  Dio get _effectiveRefreshDio =>
      _refreshDio ??
      Dio(
        BaseOptions(
          baseUrl: ApiConstants.defaultBaseUrl,
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
          sendTimeout: ApiConstants.sendTimeout,
          headers: const <String, dynamic>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Skip Bearer token injection for refresh requests
    if (_isRefreshRequest(options)) {
      return handler.next(options);
    }

    // 2. If a refresh is currently running, wait for it before dispatching
    if (_refreshCompleter != null) {
      try {
        await _refreshCompleter!.future;
      } on Object catch (_) {
        // Silently proceed if refresh fails; the request will proceed or fail naturally.
      }
    }

    // 3. Attach Bearer token if not explicitly provided
    if (!options.headers.containsKey(ApiConstants.authHeader)) {
      final accessToken = await _secureStorageService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers[ApiConstants.authHeader] =
            '${ApiConstants.bearerPrefix}$accessToken';
      }
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 1. Prevent recursion: Never attempt refresh on the refresh endpoint itself
    if (_isRefreshRequest(err.requestOptions)) {
      final code = _extractErrorCode(err);
      final statusCode = err.response?.statusCode;
      if (statusCode == 401 ||
          code == 'TOKEN_REVOKED' ||
          code == 'INVALID_TOKEN' ||
          code == 'UNAUTHORIZED') {
        await _secureStorageService.clearTokens();
        _onSessionRevoked?.call();
      }
      return handler.next(err);
    }

    // 2. Only handle 401 TOKEN_EXPIRED errors
    if (!_isTokenExpired(err)) {
      return handler.next(err);
    }

    // 3. Prevent infinite retry loops (maximum 1 retry)
    final retryCount =
        (err.requestOptions.extra[retryCountExtraKey] as int?) ?? 0;
    if (retryCount >= 1) {
      return handler.next(err);
    }

    // 4. Sequential queue check: If another request already rotated the token,
    // the stored token will differ from the token used on this request.
    final requestToken = _extractBearerToken(err.requestOptions);
    final currentStoredToken = await _secureStorageService.getAccessToken();
    if (currentStoredToken != null &&
        requestToken != null &&
        currentStoredToken != requestToken) {
      return _retry(
        err.requestOptions,
        handler,
        newAccessToken: currentStoredToken,
      );
    }

    // 5. In-flight refresh lock: If a refresh is already underway, wait for it
    if (_refreshCompleter != null) {
      final success = await _refreshCompleter!.future;
      if (success) {
        final latestToken = await _secureStorageService.getAccessToken();
        return _retry(
          err.requestOptions,
          handler,
          newAccessToken: latestToken,
        );
      } else {
        return handler.next(err);
      }
    }

    // 6. Initiate single refresh operation
    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final success = await _performRefresh();
      completer.complete(success);

      if (success) {
        final newAccessToken = await _secureStorageService.getAccessToken();
        return _retry(
          err.requestOptions,
          handler,
          newAccessToken: newAccessToken,
        );
      } else {
        return handler.next(err);
      }
    } on Object catch (_) {
      completer.complete(false);
      return handler.next(err);
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _secureStorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _secureStorageService.clearTokens();
      _onSessionRevoked?.call();
      return false;
    }

    try {
      final TokenModel tokenModel;
      if (_refreshHandler != null) {
        tokenModel = await _refreshHandler(refreshToken);
      } else {
        final response = await _effectiveRefreshDio.post<dynamic>(
          ApiConstants.refreshPath,
          data: <String, dynamic>{
            'refreshToken': refreshToken,
          },
        );

        final dynamic body = response.data;
        if (body is! Map<String, dynamic> || body['data'] == null) {
          throw const FormatException('Invalid refresh response envelope');
        }

        final data = body['data'] as Map<String, dynamic>;
        final tokens = data['tokens'] as Map<String, dynamic>?;
        if (tokens == null) {
          throw const FormatException(
            'Missing tokens object in refresh response',
          );
        }

        tokenModel = TokenModel.fromJson(tokens);
      }

      await _secureStorageService.saveTokens(
        accessToken: tokenModel.accessToken,
        refreshToken: tokenModel.refreshToken,
      );
      return true;
    } on DioException catch (dioErr) {
      final code = _extractErrorCode(dioErr);
      final status = dioErr.response?.statusCode;
      if (status == 401 ||
          status == 400 ||
          status == 403 ||
          code == 'TOKEN_REVOKED' ||
          code == 'INVALID_TOKEN' ||
          code == 'UNAUTHORIZED') {
        await _secureStorageService.clearTokens();
        _onSessionRevoked?.call();
      }
      return false;
    } on Object catch (_) {
      await _secureStorageService.clearTokens();
      _onSessionRevoked?.call();
      return false;
    }
  }

  Future<void> _retry(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler, {
    String? newAccessToken,
  }) async {
    try {
      final token =
          newAccessToken ?? await _secureStorageService.getAccessToken();
      final retryCount =
          (requestOptions.extra[retryCountExtraKey] as int?) ?? 0;

      final updatedHeaders = Map<String, dynamic>.from(requestOptions.headers);
      if (token != null && token.isNotEmpty) {
        updatedHeaders[ApiConstants.authHeader] =
            '${ApiConstants.bearerPrefix}$token';
      }

      final updatedExtra = Map<String, dynamic>.from(requestOptions.extra)
        ..[retryCountExtraKey] = retryCount + 1;

      final newOptions = requestOptions.copyWith(
        headers: updatedHeaders,
        extra: updatedExtra,
      );

      final retryClient = _retryDio ?? _effectiveRefreshDio;
      final response = await retryClient.fetch<dynamic>(newOptions);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } on Object catch (e) {
      return handler.next(
        DioException(
          requestOptions: requestOptions,
          error: e,
        ),
      );
    }
  }

  bool _isRefreshRequest(RequestOptions options) {
    final path = options.path;
    return path == ApiConstants.refreshPath ||
        path.endsWith(ApiConstants.refreshPath) ||
        options.extra['isRefreshRequest'] == true;
  }

  bool _isTokenExpired(DioException err) {
    if (err.response?.statusCode != 401) {
      return false;
    }
    final code = _extractErrorCode(err);
    return code == 'TOKEN_EXPIRED';
  }

  String? _extractErrorCode(DioException err) {
    final data = err.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        return error['code'] as String?;
      }
      if (error is String) {
        return error;
      }
      if (data['code'] is String) {
        return data['code'] as String;
      }
    }
    return null;
  }

  String? _extractBearerToken(RequestOptions options) {
    final authHeader = options.headers[ApiConstants.authHeader] as String?;
    if (authHeader != null &&
        authHeader.startsWith(ApiConstants.bearerPrefix)) {
      return authHeader.substring(ApiConstants.bearerPrefix.length).trim();
    }
    return null;
  }
}

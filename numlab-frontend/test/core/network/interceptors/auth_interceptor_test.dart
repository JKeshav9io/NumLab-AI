import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/core/network/dio_client.dart';
import 'package:numlab_frontend/core/network/interceptors/auth_interceptor.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';

class MockSecureStorageService implements SecureStorageService {
  String? accessToken;
  String? refreshToken;
  int clearTokensCallCount = 0;
  int saveTokensCallCount = 0;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    saveTokensCallCount++;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> clearTokens() async {
    clearTokensCallCount++;
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<bool> hasAccessToken() async =>
      accessToken != null && accessToken!.isNotEmpty;

  @override
  Future<bool> hasRefreshToken() async =>
      refreshToken != null && refreshToken!.isNotEmpty;
}

class FakeDio extends Fake implements Dio {
  Future<Response<dynamic>> Function(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  })?
  onPost;

  Future<Response<dynamic>> Function(RequestOptions options)? onFetch;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final res = await onPost!(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return Response<T>(
      data: res.data as T?,
      headers: res.headers,
      requestOptions: res.requestOptions,
      isRedirect: res.isRedirect,
      statusCode: res.statusCode,
      statusMessage: res.statusMessage,
      redirects: res.redirects,
      extra: res.extra,
    );
  }

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) async {
    final res = await onFetch!(requestOptions);
    return Response<T>(
      data: res.data as T?,
      headers: res.headers,
      requestOptions: res.requestOptions,
      isRedirect: res.isRedirect,
      statusCode: res.statusCode,
      statusMessage: res.statusMessage,
      redirects: res.redirects,
      extra: res.extra,
    );
  }
}

class TestRequestHandler extends RequestInterceptorHandler {
  RequestOptions? nextOptions;
  Response<dynamic>? resolvedResponse;
  DioException? rejectedError;

  @override
  void next(RequestOptions requestOptions) {
    nextOptions = requestOptions;
  }

  @override
  void resolve(
    Response<dynamic> response, [
    bool callFollowingErrorInterceptor = false,
  ]) {
    resolvedResponse = response;
  }

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) {
    rejectedError = error;
  }
}

class TestErrorHandler extends ErrorInterceptorHandler {
  DioException? nextError;
  Response<dynamic>? resolvedResponse;
  DioException? rejectedError;

  @override
  void next(DioException err) {
    nextError = err;
  }

  @override
  void resolve(Response<dynamic> response) {
    resolvedResponse = response;
  }

  @override
  void reject(
    DioException err, [
    bool callFollowingErrorInterceptor = false,
  ]) {
    rejectedError = err;
  }
}

void main() {
  group('AuthInterceptor', () {
    late MockSecureStorageService mockStorage;
    late FakeDio fakeRefreshDio;
    late FakeDio fakeRetryDio;
    late AuthInterceptor interceptor;
    var sessionRevokedCalled = false;

    setUp(() {
      mockStorage = MockSecureStorageService();
      fakeRefreshDio = FakeDio();
      fakeRetryDio = FakeDio();
      sessionRevokedCalled = false;

      interceptor = AuthInterceptor(
        secureStorageService: mockStorage,
        refreshDio: fakeRefreshDio,
        retryDio: fakeRetryDio,
        onSessionRevoked: () {
          sessionRevokedCalled = true;
        },
      );
    });

    group('onRequest — Access Token Attachment', () {
      test(
        'automatically attaches Bearer token when present in storage',
        () async {
          mockStorage.accessToken = 'stored_access_jwt';
          final handler = TestRequestHandler();
          final options = RequestOptions(path: '/solve/root/bisection');

          await interceptor.onRequest(options, handler);

          expect(handler.nextOptions, isNotNull);
          expect(
            handler.nextOptions!.headers[ApiConstants.authHeader],
            'Bearer stored_access_jwt',
          );
        },
      );

      test(
        'leaves headers unchanged when no access token exists in storage',
        () async {
          final handler = TestRequestHandler();
          final options = RequestOptions(path: '/solve/root/bisection');

          await interceptor.onRequest(options, handler);

          expect(handler.nextOptions, isNotNull);
          expect(
            handler.nextOptions!.headers.containsKey(ApiConstants.authHeader),
            isFalse,
          );
        },
      );

      test(
        'preserves explicit Authorization header if already present',
        () async {
          mockStorage.accessToken = 'stored_access_jwt';
          final handler = TestRequestHandler();
          final options = RequestOptions(
            path: '/users/me',
            headers: <String, dynamic>{
              ApiConstants.authHeader: 'Bearer custom_token',
            },
          );

          await interceptor.onRequest(options, handler);

          expect(handler.nextOptions, isNotNull);
          expect(
            handler.nextOptions!.headers[ApiConstants.authHeader],
            'Bearer custom_token',
          );
        },
      );

      test(
        'does not attach Authorization header for refresh requests',
        () async {
          mockStorage.accessToken = 'stored_access_jwt';
          final handler = TestRequestHandler();
          final options = RequestOptions(path: ApiConstants.refreshPath);

          await interceptor.onRequest(options, handler);

          expect(handler.nextOptions, isNotNull);
          expect(
            handler.nextOptions!.headers.containsKey(ApiConstants.authHeader),
            isFalse,
          );
        },
      );
    });

    group('onError — Token Refresh & Retry Lifecycle', () {
      final expiredError = DioException(
        requestOptions: RequestOptions(
          path: '/users/me',
          headers: <String, dynamic>{
            ApiConstants.authHeader: 'Bearer expired_access_jwt',
          },
        ),
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/users/me'),
          data: <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'code': 'TOKEN_EXPIRED',
              'message': 'Authentication token has expired',
            },
          },
        ),
      );

      test(
        'successfully refreshes tokens, rotates storage, and retries original request',
        () async {
          mockStorage
            ..accessToken = 'expired_access_jwt'
            ..refreshToken = 'valid_refresh_jwt';

          var refreshRequested = false;
          fakeRefreshDio.onPost =
              (
                path, {
                cancelToken,
                data,
                onReceiveProgress,
                onSendProgress,
                options,
                queryParameters,
              }) async {
                expect(path, ApiConstants.refreshPath);
                if (data is Map<String, dynamic>) {
                  expect(data['refreshToken'], 'valid_refresh_jwt');
                }
                refreshRequested = true;

                return Response(
                  statusCode: 200,
                  requestOptions: RequestOptions(path: path),
                  data: <String, dynamic>{
                    'success': true,
                    'data': <String, dynamic>{
                      'tokens': <String, dynamic>{
                        'accessToken': 'new_access_jwt',
                        'refreshToken': 'new_refresh_jwt',
                        'expiresIn': 900,
                      },
                    },
                  },
                );
              };

          var retryRequested = false;
          fakeRetryDio.onFetch = (requestOptions) async {
            retryRequested = true;
            expect(
              requestOptions.headers[ApiConstants.authHeader],
              'Bearer new_access_jwt',
            );
            expect(
              requestOptions.extra[AuthInterceptor.retryCountExtraKey],
              1,
            );

            return Response(
              statusCode: 200,
              requestOptions: requestOptions,
              data: <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{'id': 'user-1'},
              },
            );
          };

          final handler = TestErrorHandler();
          await interceptor.onError(expiredError, handler);

          expect(refreshRequested, isTrue);
          expect(retryRequested, isTrue);
          expect(mockStorage.accessToken, 'new_access_jwt');
          expect(mockStorage.refreshToken, 'new_refresh_jwt');
          expect(handler.resolvedResponse, isNotNull);
          expect(handler.resolvedResponse!.statusCode, 200);
          expect(handler.nextError, isNull);
        },
      );

      test(
        'does not retry a second time if retryCount >= 1 (loop prevention)',
        () async {
          mockStorage
            ..accessToken = 'expired_access_jwt'
            ..refreshToken = 'valid_refresh_jwt';

          final alreadyRetriedError = DioException(
            requestOptions: RequestOptions(
              path: '/users/me',
              extra: <String, dynamic>{
                AuthInterceptor.retryCountExtraKey: 1,
              },
            ),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: '/users/me'),
              data: <String, dynamic>{
                'success': false,
                'error': <String, dynamic>{
                  'code': 'TOKEN_EXPIRED',
                  'message': 'Token still expired after retry',
                },
              },
            ),
          );

          final handler = TestErrorHandler();
          await interceptor.onError(alreadyRetriedError, handler);

          expect(handler.nextError, alreadyRetriedError);
          expect(handler.resolvedResponse, isNull);
        },
      );

      test(
        'passes non-401 or non-TOKEN_EXPIRED errors through without refresh',
        () async {
          mockStorage
            ..accessToken = 'access_jwt'
            ..refreshToken = 'refresh_jwt';

          final badRequestError = DioException(
            requestOptions: RequestOptions(path: '/users/me'),
            response: Response(
              statusCode: 400,
              requestOptions: RequestOptions(path: '/users/me'),
              data: <String, dynamic>{
                'success': false,
                'error': <String, dynamic>{
                  'code': 'VALIDATION_ERROR',
                  'message': 'Bad request',
                },
              },
            ),
          );

          final handler = TestErrorHandler();
          await interceptor.onError(badRequestError, handler);

          expect(handler.nextError, badRequestError);
          expect(handler.resolvedResponse, isNull);
        },
      );

      test(
        'clears storage and triggers sessionRevoked when refresh fails with TOKEN_REVOKED',
        () async {
          mockStorage
            ..accessToken = 'expired_access_jwt'
            ..refreshToken = 'revoked_refresh_jwt';

          fakeRefreshDio.onPost =
              (
                path, {
                cancelToken,
                data,
                onReceiveProgress,
                onSendProgress,
                options,
                queryParameters,
              }) async {
                throw DioException(
                  requestOptions: RequestOptions(path: path),
                  response: Response(
                    statusCode: 401,
                    requestOptions: RequestOptions(path: path),
                    data: <String, dynamic>{
                      'success': false,
                      'error': <String, dynamic>{
                        'code': 'TOKEN_REVOKED',
                        'message': 'Refresh token has been revoked',
                      },
                    },
                  ),
                );
              };

          final handler = TestErrorHandler();
          await interceptor.onError(expiredError, handler);

          expect(handler.nextError, expiredError);
          expect(mockStorage.accessToken, isNull);
          expect(mockStorage.refreshToken, isNull);
          expect(sessionRevokedCalled, isTrue);
        },
      );

      test(
        'clears storage and triggers sessionRevoked when refresh fails with INVALID_TOKEN',
        () async {
          mockStorage
            ..accessToken = 'expired_access_jwt'
            ..refreshToken = 'malformed_token';

          fakeRefreshDio.onPost =
              (
                path, {
                cancelToken,
                data,
                onReceiveProgress,
                onSendProgress,
                options,
                queryParameters,
              }) async {
                throw DioException(
                  requestOptions: RequestOptions(path: path),
                  response: Response(
                    statusCode: 401,
                    requestOptions: RequestOptions(path: path),
                    data: <String, dynamic>{
                      'success': false,
                      'error': <String, dynamic>{
                        'code': 'INVALID_TOKEN',
                        'message': 'Invalid signature or format',
                      },
                    },
                  ),
                );
              };

          final handler = TestErrorHandler();
          await interceptor.onError(expiredError, handler);

          expect(handler.nextError, expiredError);
          expect(mockStorage.accessToken, isNull);
          expect(mockStorage.refreshToken, isNull);
          expect(sessionRevokedCalled, isTrue);
        },
      );

      test(
        'clears storage immediately if refresh token is missing in storage',
        () async {
          mockStorage
            ..accessToken = 'expired_access_jwt'
            ..refreshToken = null; // Missing!

          final handler = TestErrorHandler();
          await interceptor.onError(expiredError, handler);

          expect(handler.nextError, expiredError);
          expect(mockStorage.accessToken, isNull);
          expect(sessionRevokedCalled, isTrue);
        },
      );

      test(
        'handles network failure during refresh without unhandled crash',
        () async {
          mockStorage
            ..accessToken = 'expired_access_jwt'
            ..refreshToken = 'valid_refresh_jwt';

          fakeRefreshDio.onPost =
              (
                path, {
                cancelToken,
                data,
                onReceiveProgress,
                onSendProgress,
                options,
                queryParameters,
              }) async {
                throw DioException(
                  requestOptions: RequestOptions(path: path),
                  type: DioExceptionType.connectionTimeout,
                );
              };

          final handler = TestErrorHandler();
          await interceptor.onError(expiredError, handler);

          expect(handler.nextError, expiredError);
          expect(handler.resolvedResponse, isNull);
        },
      );

      test(
        'refresh endpoint itself receiving error never causes recursion',
        () async {
          mockStorage.refreshToken = 'bad_token';

          final refreshEndpointError = DioException(
            requestOptions: RequestOptions(path: ApiConstants.refreshPath),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: ApiConstants.refreshPath),
              data: <String, dynamic>{
                'success': false,
                'error': <String, dynamic>{
                  'code': 'TOKEN_REVOKED',
                  'message': 'Refresh token has been revoked',
                },
              },
            ),
          );

          final handler = TestErrorHandler();
          await interceptor.onError(refreshEndpointError, handler);

          expect(handler.nextError, refreshEndpointError);
          expect(mockStorage.accessToken, isNull);
          expect(mockStorage.refreshToken, isNull);
          expect(sessionRevokedCalled, isTrue);
        },
      );
    });

    group('Concurrent Expired Requests & Queueing', () {
      test(
        'simultaneous expired requests share a single refresh call and all retry successfully',
        () async {
          mockStorage
            ..accessToken = 'old_access_jwt'
            ..refreshToken = 'active_refresh_jwt';

          var refreshCount = 0;
          final refreshCompleter = Completer<Response<dynamic>>();

          fakeRefreshDio.onPost =
              (
                path, {
                cancelToken,
                data,
                onReceiveProgress,
                onSendProgress,
                options,
                queryParameters,
              }) async {
                refreshCount++;
                return refreshCompleter.future;
              };

          final retriedPaths = <String>[];
          fakeRetryDio.onFetch = (requestOptions) async {
            retriedPaths.add(requestOptions.path);
            expect(
              requestOptions.headers[ApiConstants.authHeader],
              'Bearer brand_new_access_jwt',
            );
            return Response(
              statusCode: 200,
              requestOptions: requestOptions,
              data: <String, dynamic>{'success': true},
            );
          };

          final error1 = DioException(
            requestOptions: RequestOptions(
              path: '/users/me',
              headers: <String, dynamic>{
                ApiConstants.authHeader: 'Bearer old_access_jwt',
              },
            ),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: '/users/me'),
              data: <String, dynamic>{
                'success': false,
                'error': <String, dynamic>{'code': 'TOKEN_EXPIRED'},
              },
            ),
          );

          final error2 = DioException(
            requestOptions: RequestOptions(
              path: '/users/me/history',
              headers: <String, dynamic>{
                ApiConstants.authHeader: 'Bearer old_access_jwt',
              },
            ),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: '/users/me/history'),
              data: <String, dynamic>{
                'success': false,
                'error': <String, dynamic>{'code': 'TOKEN_EXPIRED'},
              },
            ),
          );

          final handler1 = TestErrorHandler();
          final handler2 = TestErrorHandler();

          // Dispatch both error handlers concurrently
          final future1 = interceptor.onError(error1, handler1);
          final future2 = interceptor.onError(error2, handler2);

          // Complete the single refresh operation
          refreshCompleter.complete(
            Response(
              statusCode: 200,
              requestOptions: RequestOptions(path: ApiConstants.refreshPath),
              data: <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'tokens': <String, dynamic>{
                    'accessToken': 'brand_new_access_jwt',
                    'refreshToken': 'brand_new_refresh_jwt',
                    'expiresIn': 900,
                  },
                },
              },
            ),
          );

          await Future.wait([future1, future2]);

          // Exactly ONE refresh request was made!
          expect(refreshCount, 1);
          expect(mockStorage.accessToken, 'brand_new_access_jwt');
          expect(mockStorage.refreshToken, 'brand_new_refresh_jwt');

          // Both requests retried and succeeded
          expect(handler1.resolvedResponse?.statusCode, 200);
          expect(handler2.resolvedResponse?.statusCode, 200);
          expect(retriedPaths, containsAll(['/users/me', '/users/me/history']));
        },
      );

      test(
        'sequential queued request whose token was already rotated retries immediately without refresh',
        () async {
          // Emulate QueuedInterceptor behavior where error 1 completed refresh,
          // so storage now has new token, but error 2 was sent with old token.
          mockStorage
            ..accessToken = 'already_rotated_access_jwt'
            ..refreshToken = 'already_rotated_refresh_jwt';

          var refreshCallCount = 0;
          fakeRefreshDio.onPost =
              (
                path, {
                cancelToken,
                data,
                onReceiveProgress,
                onSendProgress,
                options,
                queryParameters,
              }) async {
                refreshCallCount++;
                return Response(
                  statusCode: 200,
                  requestOptions: RequestOptions(path: path),
                );
              };

          var retried = false;
          fakeRetryDio.onFetch = (requestOptions) async {
            retried = true;
            expect(
              requestOptions.headers[ApiConstants.authHeader],
              'Bearer already_rotated_access_jwt',
            );
            return Response(
              statusCode: 200,
              requestOptions: requestOptions,
              data: <String, dynamic>{'success': true},
            );
          };

          final errorWithOldToken = DioException(
            requestOptions: RequestOptions(
              path: '/users/me',
              headers: <String, dynamic>{
                ApiConstants.authHeader: 'Bearer old_stale_access_jwt',
              },
            ),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: '/users/me'),
              data: <String, dynamic>{
                'success': false,
                'error': <String, dynamic>{'code': 'TOKEN_EXPIRED'},
              },
            ),
          );

          final handler = TestErrorHandler();
          await interceptor.onError(errorWithOldToken, handler);

          // Zero refresh calls made!
          expect(refreshCallCount, 0);
          expect(retried, isTrue);
          expect(handler.resolvedResponse?.statusCode, 200);
        },
      );
    });

    group('DioClient Builder Integration', () {
      test('creates Dio instance configured with AuthInterceptor', () {
        final client = DioClient.create(
          secureStorageService: mockStorage,
          baseUrl: 'http://test-api:3000/api/v1',
        );

        expect(client.options.baseUrl, 'http://test-api:3000/api/v1');
        expect(
          client.interceptors.any((i) => i is AuthInterceptor),
          isTrue,
        );
      });
    });
  });
}

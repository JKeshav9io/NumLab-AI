import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:numlab_frontend/features/auth/data/models/auth_response_model.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';

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

  Future<Response<dynamic>> Function(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  })?
  onGet;

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
    return res as Response<T>;
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final res = await onGet!(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return res as Response<T>;
  }
}

void main() {
  late FakeDio fakeDio;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    fakeDio = FakeDio();
    dataSource = AuthRemoteDataSourceImpl(dio: fakeDio);
  });

  const tEmail = 'student@example.com';
  const tPassword = 'Password123';
  const tAccessToken = 'test_access_token';
  const tRefreshToken = 'test_refresh_token';

  final tUserJson = <String, dynamic>{
    'id': 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
    'email': tEmail,
    'emailVerified': false,
    'createdAt': '2026-09-26T12:00:00.000Z',
  };

  final tTokensJson = <String, dynamic>{
    'accessToken': tAccessToken,
    'refreshToken': tRefreshToken,
    'expiresIn': 900,
  };

  final tAuthEnvelopeJson = <String, dynamic>{
    'success': true,
    'data': <String, dynamic>{
      'user': tUserJson,
      'tokens': tTokensJson,
    },
    'meta': <String, dynamic>{
      'requestId': 'req-1',
      'timestamp': '2026-09-26T12:00:00.000Z',
    },
  };

  group('register', () {
    test('should return AuthResponseModel when status is 201/200', () async {
      fakeDio.onPost =
          (
            path, {
            cancelToken,
            data,
            onReceiveProgress,
            onSendProgress,
            options,
            queryParameters,
          }) async {
            expect(path, ApiConstants.registerPath);
            final body = data! as Map<String, dynamic>;
            expect(body['email'], tEmail);
            expect(body['password'], tPassword);

            return Response<Map<String, dynamic>>(
              data: tAuthEnvelopeJson,
              statusCode: 201,
              requestOptions: RequestOptions(path: path),
            );
          };

      final result = await dataSource.register(
        email: tEmail,
        password: tPassword,
      );

      expect(result, isA<AuthResponseModel>());
      expect(result.user.email, tEmail);
      expect(result.tokens.accessToken, tAccessToken);
    });

    test('should throw DioException when register call fails', () async {
      fakeDio.onPost =
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
              type: DioExceptionType.badResponse,
              response: Response<Map<String, dynamic>>(
                statusCode: 409,
                data: <String, dynamic>{
                  'success': false,
                  'error': <String, dynamic>{
                    'code': 'CONFLICT',
                    'message': 'A user with this email address already exists',
                  },
                },
                requestOptions: RequestOptions(path: path),
              ),
            );
          };

      expect(
        () => dataSource.register(email: tEmail, password: tPassword),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('login', () {
    test('should return AuthResponseModel when login succeeds', () async {
      fakeDio.onPost =
          (
            path, {
            cancelToken,
            data,
            onReceiveProgress,
            onSendProgress,
            options,
            queryParameters,
          }) async {
            expect(path, ApiConstants.loginPath);
            final body = data! as Map<String, dynamic>;
            expect(body['email'], tEmail);
            expect(body['password'], tPassword);

            return Response<Map<String, dynamic>>(
              data: tAuthEnvelopeJson,
              statusCode: 200,
              requestOptions: RequestOptions(path: path),
            );
          };

      final result = await dataSource.login(email: tEmail, password: tPassword);

      expect(result, isA<AuthResponseModel>());
      expect(result.user.id, 'c89b7b90-1c0b-46a2-9e5b-ecf720078021');
      expect(result.tokens.refreshToken, tRefreshToken);
    });

    test('should throw DioException on invalid credentials (401)', () async {
      fakeDio.onPost =
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
              type: DioExceptionType.badResponse,
              response: Response<Map<String, dynamic>>(
                statusCode: 401,
                data: <String, dynamic>{
                  'success': false,
                  'error': <String, dynamic>{
                    'code': 'INVALID_CREDENTIALS',
                    'message': 'Invalid email or password',
                  },
                },
                requestOptions: RequestOptions(path: path),
              ),
            );
          };

      expect(
        () => dataSource.login(email: tEmail, password: tPassword),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('refresh', () {
    test('should return TokenModel when refresh succeeds', () async {
      fakeDio.onPost =
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
            final body = data! as Map<String, dynamic>;
            expect(body['refreshToken'], tRefreshToken);

            return Response<Map<String, dynamic>>(
              data: <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'tokens': tTokensJson,
                },
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: path),
            );
          };

      final result = await dataSource.refresh(refreshToken: tRefreshToken);

      expect(result, isA<TokenModel>());
      expect(result.accessToken, tAccessToken);
      expect(result.refreshToken, tRefreshToken);
      expect(result.expiresIn, 900);
    });

    test('should throw FormatException when tokens field is missing', () async {
      fakeDio.onPost =
          (
            path, {
            cancelToken,
            data,
            onReceiveProgress,
            onSendProgress,
            options,
            queryParameters,
          }) async {
            return Response<Map<String, dynamic>>(
              data: <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{},
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: path),
            );
          };

      expect(
        () => dataSource.refresh(refreshToken: tRefreshToken),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('logout and logoutAll', () {
    test('logout should post refreshToken to logout path', () async {
      var called = false;
      fakeDio.onPost =
          (
            path, {
            cancelToken,
            data,
            onReceiveProgress,
            onSendProgress,
            options,
            queryParameters,
          }) async {
            expect(path, ApiConstants.logoutPath);
            expect(
              (data! as Map<String, dynamic>)['refreshToken'],
              tRefreshToken,
            );
            called = true;
            return Response<Map<String, dynamic>>(
              data: <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{'message': 'Logged out successfully'},
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: path),
            );
          };

      await dataSource.logout(refreshToken: tRefreshToken);
      expect(called, isTrue);
    });

    test('logoutAll should post to logoutAllPath with bearer header', () async {
      var called = false;
      fakeDio.onPost =
          (
            path, {
            cancelToken,
            data,
            onReceiveProgress,
            onSendProgress,
            options,
            queryParameters,
          }) async {
            expect(path, ApiConstants.logoutAllPath);
            expect(
              options?.headers?[ApiConstants.authHeader],
              '${ApiConstants.bearerPrefix}$tAccessToken',
            );
            called = true;
            return Response<Map<String, dynamic>>(
              data: <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'message': 'Logged out of all devices successfully',
                },
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: path),
            );
          };

      await dataSource.logoutAll(accessToken: tAccessToken);
      expect(called, isTrue);
    });
  });

  group('getCurrentUser', () {
    test(
      'should parse user when backend returns direct user payload in data',
      () async {
        fakeDio.onGet =
            (
              path, {
              cancelToken,
              data,
              onReceiveProgress,
              options,
              queryParameters,
            }) async {
              expect(path, ApiConstants.userMePath);
              expect(
                options?.headers?[ApiConstants.authHeader],
                '${ApiConstants.bearerPrefix}$tAccessToken',
              );
              return Response<Map<String, dynamic>>(
                data: <String, dynamic>{
                  'success': true,
                  'data': tUserJson,
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: path),
              );
            };

        final result = await dataSource.getCurrentUser(
          accessToken: tAccessToken,
        );

        expect(result, isA<UserModel>());
        expect(result.id, 'c89b7b90-1c0b-46a2-9e5b-ecf720078021');
        expect(result.email, tEmail);
      },
    );

    test(
      'should parse user when backend returns nested user object in data',
      () async {
        fakeDio.onGet =
            (
              path, {
              cancelToken,
              data,
              onReceiveProgress,
              options,
              queryParameters,
            }) async {
              return Response<Map<String, dynamic>>(
                data: <String, dynamic>{
                  'success': true,
                  'data': <String, dynamic>{
                    'user': tUserJson,
                  },
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: path),
              );
            };

        final result = await dataSource.getCurrentUser();

        expect(result, isA<UserModel>());
        expect(result.email, tEmail);
      },
    );
  });
}

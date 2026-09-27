import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:numlab_frontend/features/auth/data/models/auth_response_model.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';
import 'package:numlab_frontend/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthRemoteDataSource extends Fake implements AuthRemoteDataSource {
  Future<AuthResponseModel> Function({
    required String email,
    required String password,
  })?
  onRegister;
  Future<AuthResponseModel> Function({
    required String email,
    required String password,
  })?
  onLogin;
  Future<TokenModel> Function({required String refreshToken})? onRefresh;
  Future<void> Function({required String refreshToken})? onLogout;
  Future<void> Function({String? accessToken})? onLogoutAll;
  Future<UserModel> Function({String? accessToken})? onGetCurrentUser;

  @override
  Future<AuthResponseModel> register({
    required String email,
    required String password,
  }) {
    return onRegister!(email: email, password: password);
  }

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) {
    return onLogin!(email: email, password: password);
  }

  @override
  Future<TokenModel> refresh({required String refreshToken}) {
    return onRefresh!(refreshToken: refreshToken);
  }

  @override
  Future<void> logout({required String refreshToken}) {
    return onLogout!(refreshToken: refreshToken);
  }

  @override
  Future<void> logoutAll({String? accessToken}) {
    return onLogoutAll!(accessToken: accessToken);
  }

  @override
  Future<UserModel> getCurrentUser({String? accessToken}) {
    return onGetCurrentUser!(accessToken: accessToken);
  }
}

void main() {
  late MockAuthRemoteDataSource mockDataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(remoteDataSource: mockDataSource);
  });

  const tEmail = 'student@example.com';
  const tPassword = 'Password123';
  const tAccessToken = 'test_access_jwt';
  const tRefreshToken = 'test_refresh_jwt';

  final tUser = UserModel(
    id: 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
    email: tEmail,
    emailVerified: false,
    createdAt: DateTime.parse('2026-09-26T12:00:00.000Z'),
  );

  const tTokens = TokenModel(
    accessToken: tAccessToken,
    refreshToken: tRefreshToken,
    expiresIn: 900,
  );

  final tAuthResponse = AuthResponseModel(
    user: tUser,
    tokens: tTokens,
  );

  group('register', () {
    test(
      'should return Right(AuthResponseModel) when registration succeeds',
      () async {
        mockDataSource.onRegister =
            ({required email, required password}) async {
              return tAuthResponse;
            };

        final result = await repository.register(
          email: tEmail,
          password: tPassword,
        );

        expect(result, Right<Failure, AuthResponseModel>(tAuthResponse));
      },
    );

    test('should return Left(ServerFailure) on 409 conflict error', () async {
      mockDataSource.onRegister = ({required email, required password}) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/auth/register'),
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
            requestOptions: RequestOptions(path: '/auth/register'),
          ),
        );
      };

      final result = await repository.register(
        email: tEmail,
        password: tPassword,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.code, 'CONFLICT');
          expect(
            failure.message,
            'A user with this email address already exists',
          );
        },
        (_) => fail('Should return Left'),
      );
    });
  });

  group('login', () {
    test(
      'should return Right(AuthResponseModel) when login succeeds',
      () async {
        mockDataSource.onLogin = ({required email, required password}) async {
          return tAuthResponse;
        };

        final result = await repository.login(
          email: tEmail,
          password: tPassword,
        );

        expect(result, Right<Failure, AuthResponseModel>(tAuthResponse));
      },
    );

    test(
      'should return Left(AuthFailure) on 401 INVALID_CREDENTIALS',
      () async {
        mockDataSource.onLogin = ({required email, required password}) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/auth/login'),
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
              requestOptions: RequestOptions(path: '/auth/login'),
            ),
          );
        };

        final result = await repository.login(
          email: tEmail,
          password: tPassword,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<AuthFailure>());
            expect(failure.code, 'INVALID_CREDENTIALS');
          },
          (_) => fail('Should return Left'),
        );
      },
    );
  });

  group('refresh', () {
    test('should return Right(TokenModel) when refresh succeeds', () async {
      mockDataSource.onRefresh = ({required refreshToken}) async {
        return tTokens;
      };

      final result = await repository.refresh(refreshToken: tRefreshToken);

      expect(result, const Right<Failure, TokenModel>(tTokens));
    });

    test('should return Left(AuthFailure) on 401 TOKEN_REVOKED', () async {
      mockDataSource.onRefresh = ({required refreshToken}) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            statusCode: 401,
            data: <String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'code': 'TOKEN_REVOKED',
                'message': 'Refresh token is invalid or has been revoked',
              },
            },
            requestOptions: RequestOptions(path: '/auth/refresh'),
          ),
        );
      };

      final result = await repository.refresh(refreshToken: tRefreshToken);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'TOKEN_REVOKED');
        },
        (_) => fail('Should return Left'),
      );
    });
  });

  group('logout and logoutAll', () {
    test('logout should return Right(null) on success', () async {
      mockDataSource.onLogout = ({required refreshToken}) async {};

      final result = await repository.logout(refreshToken: tRefreshToken);

      expect(result, const Right<Failure, void>(null));
    });

    test('logoutAll should return Right(null) on success', () async {
      mockDataSource.onLogoutAll = ({accessToken}) async {};

      final result = await repository.logoutAll(accessToken: tAccessToken);

      expect(result, const Right<Failure, void>(null));
    });

    test(
      'logoutAll should return Left(AuthFailure) on 401 UNAUTHORIZED',
      () async {
        mockDataSource.onLogoutAll = ({accessToken}) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/auth/logout-all'),
            type: DioExceptionType.badResponse,
            response: Response<Map<String, dynamic>>(
              statusCode: 401,
              data: <String, dynamic>{
                'success': false,
                'error': <String, dynamic>{
                  'code': 'UNAUTHORIZED',
                  'message': 'Missing or invalid Bearer token',
                },
              },
              requestOptions: RequestOptions(path: '/auth/logout-all'),
            ),
          );
        };

        final result = await repository.logoutAll(accessToken: tAccessToken);

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<AuthFailure>()),
          (_) => fail('Should return Left'),
        );
      },
    );
  });

  group('getCurrentUser', () {
    test('should return Right(UserModel) on success', () async {
      mockDataSource.onGetCurrentUser = ({accessToken}) async {
        return tUser;
      };

      final result = await repository.getCurrentUser(accessToken: tAccessToken);

      expect(result, Right<Failure, UserModel>(tUser));
    });

    test('should return Left(NetworkFailure) on connection timeout', () async {
      mockDataSource.onGetCurrentUser = ({accessToken}) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/users/me'),
          type: DioExceptionType.connectionTimeout,
        );
      };

      final result = await repository.getCurrentUser(accessToken: tAccessToken);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<NetworkFailure>());
        },
        (_) => fail('Should return Left'),
      );
    });

    test(
      'should return Left(ServerFailure) on unexpected FormatException without leaking',
      () async {
        mockDataSource.onGetCurrentUser = ({accessToken}) async {
          throw const FormatException('Corrupt data');
        };

        final result = await repository.getCurrentUser(
          accessToken: tAccessToken,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
          },
          (_) => fail('Should return Left'),
        );
      },
    );
  });
}

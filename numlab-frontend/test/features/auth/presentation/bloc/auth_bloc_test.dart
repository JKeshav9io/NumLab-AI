import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/auth/domain/entities/auth_result.dart';
import 'package:numlab_frontend/features/auth/domain/entities/token.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';

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

class MockLoginUseCase extends Fake implements LoginUseCase {
  Future<Either<Failure, AuthResult>> Function({
    required String email,
    required String password,
  })?
  handler;

  @override
  Future<Either<Failure, AuthResult>> call({
    required String email,
    required String password,
  }) async => handler!(email: email, password: password);
}

class MockRegisterUseCase extends Fake implements RegisterUseCase {
  Future<Either<Failure, AuthResult>> Function({
    required String email,
    required String password,
  })?
  handler;

  @override
  Future<Either<Failure, AuthResult>> call({
    required String email,
    required String password,
  }) async => handler!(email: email, password: password);
}

class MockRefreshTokenUseCase extends Fake implements RefreshTokenUseCase {
  Future<Either<Failure, Token>> Function({
    required String refreshToken,
  })?
  handler;

  @override
  Future<Either<Failure, Token>> call({
    required String refreshToken,
  }) async => handler!(refreshToken: refreshToken);
}

class MockLogoutUseCase extends Fake implements LogoutUseCase {
  Future<Either<Failure, void>> Function({
    required String refreshToken,
  })?
  handler;

  @override
  Future<Either<Failure, void>> call({
    required String refreshToken,
  }) async => handler!(refreshToken: refreshToken);
}

class MockLogoutAllUseCase extends Fake implements LogoutAllUseCase {
  Future<Either<Failure, void>> Function({
    String? accessToken,
  })?
  handler;

  @override
  Future<Either<Failure, void>> call({
    String? accessToken,
  }) async => handler!(accessToken: accessToken);
}

class MockGetCurrentUserUseCase extends Fake implements GetCurrentUserUseCase {
  Future<Either<Failure, User>> Function({
    String? accessToken,
  })?
  handler;

  @override
  Future<Either<Failure, User>> call({
    String? accessToken,
  }) async => handler!(accessToken: accessToken);
}

void main() {
  group('AuthBloc', () {
    late MockSecureStorageService mockStorage;
    late MockLoginUseCase mockLoginUseCase;
    late MockRegisterUseCase mockRegisterUseCase;
    late MockRefreshTokenUseCase mockRefreshTokenUseCase;
    late MockLogoutUseCase mockLogoutUseCase;
    late MockLogoutAllUseCase mockLogoutAllUseCase;
    late MockGetCurrentUserUseCase mockGetCurrentUserUseCase;
    late AuthBloc authBloc;

    final tUser = User(
      id: 'user-uuid-1',
      email: 'student@example.com',
      emailVerified: true,
      createdAt: DateTime.parse('2026-09-26T12:00:00.000Z'),
    );

    const tToken = Token(
      accessToken: 'access_jwt_123',
      refreshToken: 'refresh_jwt_456',
      expiresIn: 900,
    );

    final tAuthResult = AuthResult(
      user: tUser,
      tokens: tToken,
    );

    setUp(() {
      mockStorage = MockSecureStorageService();
      mockLoginUseCase = MockLoginUseCase();
      mockRegisterUseCase = MockRegisterUseCase();
      mockRefreshTokenUseCase = MockRefreshTokenUseCase();
      mockLogoutUseCase = MockLogoutUseCase();
      mockLogoutAllUseCase = MockLogoutAllUseCase();
      mockGetCurrentUserUseCase = MockGetCurrentUserUseCase();

      authBloc = AuthBloc(
        secureStorageService: mockStorage,
        loginUseCase: mockLoginUseCase,
        registerUseCase: mockRegisterUseCase,
        refreshTokenUseCase: mockRefreshTokenUseCase,
        logoutUseCase: mockLogoutUseCase,
        logoutAllUseCase: mockLogoutAllUseCase,
        getCurrentUserUseCase: mockGetCurrentUserUseCase,
      );
    });

    tearDown(() async {
      await authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, const AuthInitial());
    });

    group('AuthInitializeRequested', () {
      test(
        'emits [AuthLoading, AuthUnauthenticated] when no refresh token is persisted',
        () async {
          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthUnauthenticated(),
            ]),
          );

          authBloc.add(const AuthInitializeRequested());
          await expectation;
        },
      );

      test(
        'emits [AuthLoading, AuthAuthenticated] when session restores successfully',
        () async {
          mockStorage.refreshToken = 'persisted_refresh_jwt';
          mockGetCurrentUserUseCase.handler = ({accessToken}) async =>
              Right(tUser);

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(<AuthState>[
              const AuthLoading(),
              AuthAuthenticated(user: tUser),
            ]),
          );

          authBloc.add(const AuthInitializeRequested());
          await expectation;
        },
      );

      test(
        'clears tokens and emits [AuthLoading, AuthUnauthenticated] when restore returns AuthFailure',
        () async {
          mockStorage
            ..accessToken = 'stale_access'
            ..refreshToken = 'revoked_refresh';
          mockGetCurrentUserUseCase.handler = ({accessToken}) async =>
              const Left(
                AuthFailure(message: 'Session revoked', code: 'TOKEN_REVOKED'),
              );

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthUnauthenticated(),
            ]),
          );

          authBloc.add(const AuthInitializeRequested());
          await expectation;

          expect(mockStorage.accessToken, isNull);
          expect(mockStorage.refreshToken, isNull);
        },
      );

      test(
        'emits [AuthLoading, AuthError] when restore fails with NetworkFailure',
        () async {
          mockStorage.refreshToken = 'persisted_refresh_jwt';
          const networkFailure = NetworkFailure(message: 'Server unreachable');
          mockGetCurrentUserUseCase.handler = ({accessToken}) async =>
              const Left(networkFailure);

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthError(failure: networkFailure),
            ]),
          );

          authBloc.add(const AuthInitializeRequested());
          await expectation;
        },
      );
    });

    group('AuthLoginRequested', () {
      test(
        'emits [AuthLoading, AuthAuthenticated] and saves tokens upon successful login',
        () async {
          mockLoginUseCase.handler =
              ({required email, required password}) async => Right(tAuthResult);

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(<AuthState>[
              const AuthLoading(),
              AuthAuthenticated(user: tUser),
            ]),
          );

          authBloc.add(
            const AuthLoginRequested(
              email: 'student@example.com',
              password: 'Password123',
            ),
          );

          await expectation;

          expect(mockStorage.accessToken, 'access_jwt_123');
          expect(mockStorage.refreshToken, 'refresh_jwt_456');
        },
      );

      test(
        'emits [AuthLoading, AuthError] upon failed login',
        () async {
          const authFailure = AuthFailure(
            message: 'Invalid email or password',
            code: 'INVALID_CREDENTIALS',
          );
          mockLoginUseCase.handler =
              ({required email, required password}) async =>
                  const Left(authFailure);

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthError(failure: authFailure),
            ]),
          );

          authBloc.add(
            const AuthLoginRequested(
              email: 'student@example.com',
              password: 'WrongPassword',
            ),
          );

          await expectation;
        },
      );
    });

    group('AuthRegisterRequested', () {
      test(
        'emits [AuthLoading, AuthAuthenticated] and saves tokens upon successful registration',
        () async {
          mockRegisterUseCase.handler =
              ({required email, required password}) async => Right(tAuthResult);

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(<AuthState>[
              const AuthLoading(),
              AuthAuthenticated(user: tUser),
            ]),
          );

          authBloc.add(
            const AuthRegisterRequested(
              email: 'student@example.com',
              password: 'Password123',
            ),
          );

          await expectation;

          expect(mockStorage.accessToken, 'access_jwt_123');
          expect(mockStorage.refreshToken, 'refresh_jwt_456');
        },
      );

      test(
        'emits [AuthLoading, AuthError] upon registration validation failure',
        () async {
          const valFailure = ValidationFailure(
            message: 'Email already registered',
          );
          mockRegisterUseCase.handler =
              ({required email, required password}) async =>
                  const Left(valFailure);

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthError(failure: valFailure),
            ]),
          );

          authBloc.add(
            const AuthRegisterRequested(
              email: 'existing@example.com',
              password: 'Password123',
            ),
          );

          await expectation;
        },
      );
    });

    group('AuthLogoutRequested', () {
      test(
        'calls logout usecase, purges secure storage, and emits [AuthLoading, AuthUnauthenticated]',
        () async {
          mockStorage
            ..accessToken = 'active_access'
            ..refreshToken = 'active_refresh';

          var logoutCalledWith = '';
          mockLogoutUseCase.handler = ({required refreshToken}) async {
            logoutCalledWith = refreshToken;
            return const Right(null);
          };

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthUnauthenticated(),
            ]),
          );

          authBloc.add(const AuthLogoutRequested());
          await expectation;

          expect(logoutCalledWith, 'active_refresh');
          expect(mockStorage.accessToken, isNull);
          expect(mockStorage.refreshToken, isNull);
        },
      );

      test(
        'purges secure storage and emits [AuthLoading, AuthUnauthenticated] even if storage has no token',
        () async {
          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthUnauthenticated(),
            ]),
          );

          authBloc.add(const AuthLogoutRequested());
          await expectation;

          expect(mockStorage.accessToken, isNull);
          expect(mockStorage.refreshToken, isNull);
        },
      );
    });

    group('AuthLogoutAllRequested', () {
      test(
        'calls logoutAll with access token, purges secure storage, and emits [AuthLoading, AuthUnauthenticated]',
        () async {
          mockStorage
            ..accessToken = 'user_access_jwt'
            ..refreshToken = 'user_refresh_jwt';

          var logoutAllToken = '';
          mockLogoutAllUseCase.handler = ({accessToken}) async {
            logoutAllToken = accessToken ?? '';
            return const Right(null);
          };

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthUnauthenticated(),
            ]),
          );

          authBloc.add(const AuthLogoutAllRequested());
          await expectation;

          expect(logoutAllToken, 'user_access_jwt');
          expect(mockStorage.accessToken, isNull);
          expect(mockStorage.refreshToken, isNull);
        },
      );
    });

    group('AuthSessionRefreshRequested', () {
      test(
        'emits [AuthLoading, AuthUnauthenticated] if refresh token is missing in storage',
        () async {
          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthUnauthenticated(),
            ]),
          );

          authBloc.add(const AuthSessionRefreshRequested());
          await expectation;
        },
      );

      test(
        'rotates tokens, saves them, fetches user, and emits [AuthLoading, AuthAuthenticated]',
        () async {
          mockStorage.refreshToken = 'old_refresh_jwt';

          const rotatedTokens = Token(
            accessToken: 'rotated_access_jwt',
            refreshToken: 'rotated_refresh_jwt',
            expiresIn: 900,
          );

          mockRefreshTokenUseCase.handler = ({required refreshToken}) async {
            expect(refreshToken, 'old_refresh_jwt');
            return const Right(rotatedTokens);
          };

          mockGetCurrentUserUseCase.handler = ({accessToken}) async =>
              Right(tUser);

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(<AuthState>[
              const AuthLoading(),
              AuthAuthenticated(user: tUser),
            ]),
          );

          authBloc.add(const AuthSessionRefreshRequested());
          await expectation;

          expect(mockStorage.accessToken, 'rotated_access_jwt');
          expect(mockStorage.refreshToken, 'rotated_refresh_jwt');
        },
      );

      test(
        'clears storage and emits [AuthLoading, AuthUnauthenticated] when refresh returns AuthFailure',
        () async {
          mockStorage.refreshToken = 'revoked_token';

          mockRefreshTokenUseCase.handler = ({required refreshToken}) async =>
              const Left(
                AuthFailure(message: 'Token revoked', code: 'TOKEN_REVOKED'),
              );

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthUnauthenticated(),
            ]),
          );

          authBloc.add(const AuthSessionRefreshRequested());
          await expectation;

          expect(mockStorage.accessToken, isNull);
          expect(mockStorage.refreshToken, isNull);
        },
      );
    });

    group('AuthGetCurrentUserRequested', () {
      test(
        'emits [AuthLoading, AuthAuthenticated] when getCurrentUser succeeds',
        () async {
          mockGetCurrentUserUseCase.handler = ({accessToken}) async =>
              Right(tUser);

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(<AuthState>[
              const AuthLoading(),
              AuthAuthenticated(user: tUser),
            ]),
          );

          authBloc.add(const AuthGetCurrentUserRequested());
          await expectation;
        },
      );

      test(
        'clears tokens and emits [AuthLoading, AuthUnauthenticated] when getCurrentUser returns AuthFailure',
        () async {
          mockStorage.accessToken = 'expired_token';
          mockGetCurrentUserUseCase.handler = ({accessToken}) async =>
              const Left(AuthFailure(message: 'Unauthorized'));

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthLoading(),
              AuthUnauthenticated(),
            ]),
          );

          authBloc.add(const AuthGetCurrentUserRequested());
          await expectation;

          expect(mockStorage.accessToken, isNull);
        },
      );
    });

    group('AuthSessionRevoked', () {
      test(
        'purges credentials and transitions immediately to AuthUnauthenticated',
        () async {
          mockStorage
            ..accessToken = 'some_access'
            ..refreshToken = 'some_refresh';

          final expectation = expectLater(
            authBloc.stream,
            emitsInOrder(const <AuthState>[
              AuthUnauthenticated(),
            ]),
          );

          authBloc.add(const AuthSessionRevoked());
          await expectation;

          expect(mockStorage.accessToken, isNull);
          expect(mockStorage.refreshToken, isNull);
        },
      );
    });

    group('State & Failure Mapping Details', () {
      test('AuthError exposes failure message and props properly', () {
        const failure = ServerFailure(message: 'Database connection failed');
        const state = AuthError(failure: failure);

        expect(state.message, 'Database connection failed');
        expect(state.props, [failure]);
      });

      test(
        'AuthLoading and AuthUnauthenticated support optional messages and props equality',
        () {
          expect(
            const AuthLoading(message: 'Signing in'),
            const AuthLoading(message: 'Signing in'),
          );
          expect(
            const AuthLoading(message: 'A'),
            isNot(const AuthLoading(message: 'B')),
          );
          expect(
            const AuthUnauthenticated(message: 'Expired'),
            const AuthUnauthenticated(message: 'Expired'),
          );
        },
      );
    });
  });
}

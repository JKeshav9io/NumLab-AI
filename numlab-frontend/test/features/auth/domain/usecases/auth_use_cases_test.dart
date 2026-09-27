import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/data/models/auth_response_model.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';
import 'package:numlab_frontend/features/auth/domain/entities/entities.dart';
import 'package:numlab_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:numlab_frontend/features/auth/domain/usecases/usecases.dart';

class MockAuthRepository extends Fake implements AuthRepository {
  Future<Either<Failure, AuthResponseModel>> Function({
    required String email,
    required String password,
  })?
  onRegister;

  Future<Either<Failure, AuthResponseModel>> Function({
    required String email,
    required String password,
  })?
  onLogin;

  Future<Either<Failure, TokenModel>> Function({
    required String refreshToken,
  })?
  onRefresh;

  Future<Either<Failure, void>> Function({
    required String refreshToken,
  })?
  onLogout;

  Future<Either<Failure, void>> Function({
    String? accessToken,
  })?
  onLogoutAll;

  Future<Either<Failure, UserModel>> Function({
    String? accessToken,
  })?
  onGetCurrentUser;

  @override
  Future<Either<Failure, AuthResponseModel>> register({
    required String email,
    required String password,
  }) {
    return onRegister!(email: email, password: password);
  }

  @override
  Future<Either<Failure, AuthResponseModel>> login({
    required String email,
    required String password,
  }) {
    return onLogin!(email: email, password: password);
  }

  @override
  Future<Either<Failure, TokenModel>> refresh({
    required String refreshToken,
  }) {
    return onRefresh!(refreshToken: refreshToken);
  }

  @override
  Future<Either<Failure, void>> logout({
    required String refreshToken,
  }) {
    return onLogout!(refreshToken: refreshToken);
  }

  @override
  Future<Either<Failure, void>> logoutAll({
    String? accessToken,
  }) {
    return onLogoutAll!(accessToken: accessToken);
  }

  @override
  Future<Either<Failure, UserModel>> getCurrentUser({
    String? accessToken,
  }) {
    return onGetCurrentUser!(accessToken: accessToken);
  }
}

void main() {
  late MockAuthRepository mockRepository;
  final now = DateTime.parse('2026-09-27T00:00:00.000Z');

  final testUserModel = UserModel(
    id: 'user-1',
    email: 'test@example.com',
    emailVerified: false,
    createdAt: now,
  );

  const testTokenModel = TokenModel(
    accessToken: 'access-token-123',
    refreshToken: 'refresh-token-456',
    expiresIn: 900,
  );

  final testAuthResponseModel = AuthResponseModel(
    user: testUserModel,
    tokens: testTokenModel,
  );

  setUp(() {
    mockRepository = MockAuthRepository();
  });

  group('RegisterUseCase', () {
    late RegisterUseCase useCase;

    setUp(() {
      useCase = RegisterUseCase(mockRepository);
    });

    test('returns Right(AuthResult) when registration succeeds', () async {
      mockRepository.onRegister = ({required email, required password}) async {
        return Right(testAuthResponseModel);
      };

      final result = await useCase(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (authResult) {
          expect(authResult, isA<AuthResult>());
          expect(authResult.user.id, 'user-1');
          expect(authResult.tokens.accessToken, 'access-token-123');
        },
      );
    });

    test('propagates Left(Failure) when registration fails', () async {
      mockRepository.onRegister = ({required email, required password}) async {
        return const Left(
          ServerFailure(message: 'Email already in use', statusCode: 409),
        );
      };

      final result = await useCase(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Email already in use');
        },
        (_) => fail('Should fail'),
      );
    });
  });

  group('LoginUseCase', () {
    late LoginUseCase useCase;

    setUp(() {
      useCase = LoginUseCase(mockRepository);
    });

    test('returns Right(AuthResult) when login succeeds', () async {
      mockRepository.onLogin = ({required email, required password}) async {
        return Right(testAuthResponseModel);
      };

      final result = await useCase(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (authResult) {
          expect(authResult, isA<AuthResult>());
          expect(authResult.user.email, 'test@example.com');
          expect(authResult.tokens.refreshToken, 'refresh-token-456');
        },
      );
    });

    test('propagates Left(AuthFailure) on invalid credentials', () async {
      mockRepository.onLogin = ({required email, required password}) async {
        return const Left(
          AuthFailure(
            message: 'Invalid credentials',
            code: 'INVALID_CREDENTIALS',
          ),
        );
      };

      final result = await useCase(
        email: 'test@example.com',
        password: 'wrongpassword',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'INVALID_CREDENTIALS');
        },
        (_) => fail('Should fail'),
      );
    });
  });

  group('RefreshTokenUseCase', () {
    late RefreshTokenUseCase useCase;

    setUp(() {
      useCase = RefreshTokenUseCase(mockRepository);
    });

    test('returns Right(Token) when token refresh succeeds', () async {
      mockRepository.onRefresh = ({required refreshToken}) async {
        return const Right(testTokenModel);
      };

      final result = await useCase(refreshToken: 'valid-refresh-token');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (token) {
          expect(token, isA<Token>());
          expect(token.accessToken, 'access-token-123');
        },
      );
    });

    test('propagates Left(AuthFailure) when refresh token revoked', () async {
      mockRepository.onRefresh = ({required refreshToken}) async {
        return const Left(
          AuthFailure(message: 'Token revoked', code: 'TOKEN_REVOKED'),
        );
      };

      final result = await useCase(refreshToken: 'revoked-token');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'TOKEN_REVOKED');
        },
        (_) => fail('Should fail'),
      );
    });
  });

  group('LogoutUseCase', () {
    late LogoutUseCase useCase;

    setUp(() {
      useCase = LogoutUseCase(mockRepository);
    });

    test('returns Right(null) when logout succeeds', () async {
      mockRepository.onLogout = ({required refreshToken}) async {
        return const Right(null);
      };

      final result = await useCase(refreshToken: 'refresh-token');

      expect(result, const Right<Failure, void>(null));
    });

    test('propagates Left(Failure) on network error', () async {
      mockRepository.onLogout = ({required refreshToken}) async {
        return const Left(NetworkFailure(message: 'Connection timed out'));
      };

      final result = await useCase(refreshToken: 'refresh-token');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Should fail'),
      );
    });
  });

  group('LogoutAllUseCase', () {
    late LogoutAllUseCase useCase;

    setUp(() {
      useCase = LogoutAllUseCase(mockRepository);
    });

    test('returns Right(null) when logoutAll succeeds', () async {
      mockRepository.onLogoutAll = ({accessToken}) async {
        return const Right(null);
      };

      final result = await useCase(accessToken: 'bearer-token');

      expect(result, const Right<Failure, void>(null));
    });

    test('propagates Left(AuthFailure) when unauthorized', () async {
      mockRepository.onLogoutAll = ({accessToken}) async {
        return const Left(
          AuthFailure(message: 'Unauthorized'),
        );
      };

      final result = await useCase(accessToken: 'bad-token');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Should fail'),
      );
    });
  });

  group('GetCurrentUserUseCase', () {
    late GetCurrentUserUseCase useCase;

    setUp(() {
      useCase = GetCurrentUserUseCase(mockRepository);
    });

    test('returns Right(User) when fetching profile succeeds', () async {
      mockRepository.onGetCurrentUser = ({accessToken}) async {
        return Right(testUserModel);
      };

      final result = await useCase(accessToken: 'bearer-token');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (user) {
          expect(user, isA<User>());
          expect(user.id, 'user-1');
          expect(user.email, 'test@example.com');
        },
      );
    });

    test('propagates Left(Failure) when user profile fetch fails', () async {
      mockRepository.onGetCurrentUser = ({accessToken}) async {
        return const Left(
          ServerFailure(message: 'Database connection error'),
        );
      };

      final result = await useCase();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Database connection error');
        },
        (_) => fail('Should fail'),
      );
    });
  });
}

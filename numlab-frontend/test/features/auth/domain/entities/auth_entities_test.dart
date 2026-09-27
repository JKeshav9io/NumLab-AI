import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/auth/data/models/auth_response_model.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';
import 'package:numlab_frontend/features/auth/domain/entities/entities.dart';

void main() {
  final now = DateTime.parse('2026-09-27T00:00:00.000Z');

  group('User entity', () {
    test('instantiates with all fields and maintains value equality', () {
      final u1 = User(
        id: 'u-1',
        email: 'user@example.com',
        emailVerified: true,
        createdAt: now,
        lastLoginAt: now,
        updatedAt: now,
      );
      final u2 = User(
        id: 'u-1',
        email: 'user@example.com',
        emailVerified: true,
        createdAt: now,
        lastLoginAt: now,
        updatedAt: now,
      );

      expect(u1, equals(u2));
      expect(u1.id, 'u-1');
      expect(u1.email, 'user@example.com');
      expect(u1.emailVerified, isTrue);
    });

    test('converts between UserModel and User entity seamlessly', () {
      final model = UserModel(
        id: 'u-1',
        email: 'user@example.com',
        emailVerified: true,
        createdAt: now,
        lastLoginAt: now,
        updatedAt: now,
      );

      expect(model, isA<User>());

      final entity = model.toEntity();
      expect(entity, isA<User>());
      expect(entity.id, model.id);
      expect(entity.email, model.email);

      final reconstructedModel = UserModel.fromEntity(entity);
      expect(reconstructedModel, equals(model));
    });
  });

  group('Token entity', () {
    test('instantiates with all fields and maintains value equality', () {
      const t1 = Token(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        expiresIn: 900,
      );
      const t2 = Token(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        expiresIn: 900,
      );

      expect(t1, equals(t2));
      expect(t1.accessToken, 'access-123');
      expect(t1.refreshToken, 'refresh-456');
      expect(t1.expiresIn, 900);
    });

    test('converts between TokenModel and Token entity seamlessly', () {
      const model = TokenModel(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        expiresIn: 900,
      );

      expect(model, isA<Token>());

      final entity = model.toEntity();
      expect(entity, isA<Token>());
      expect(entity.accessToken, model.accessToken);

      final reconstructedModel = TokenModel.fromEntity(entity);
      expect(reconstructedModel, equals(model));
    });
  });

  group('AuthResult entity', () {
    test('instantiates with user and tokens and maintains value equality', () {
      final user = User(
        id: 'u-1',
        email: 'user@example.com',
        emailVerified: false,
        createdAt: now,
      );
      const token = Token(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        expiresIn: 900,
      );

      final r1 = AuthResult(user: user, tokens: token);
      final r2 = AuthResult(user: user, tokens: token);

      expect(r1, equals(r2));
      expect(r1.user.id, 'u-1');
      expect(r1.tokens.accessToken, 'access-123');
    });

    test('converts between AuthResponseModel and AuthResult entity', () {
      final userModel = UserModel(
        id: 'u-1',
        email: 'user@example.com',
        emailVerified: true,
        createdAt: now,
      );
      const tokenModel = TokenModel(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        expiresIn: 900,
      );

      final responseModel = AuthResponseModel(
        user: userModel,
        tokens: tokenModel,
      );

      expect(responseModel, isA<AuthResult>());

      final resultEntity = responseModel.toEntity();
      expect(resultEntity, isA<AuthResult>());
      expect(resultEntity.user.id, 'u-1');
      expect(resultEntity.tokens.accessToken, 'access-123');
    });
  });
}

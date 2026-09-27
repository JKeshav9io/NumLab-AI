import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/auth/data/models/auth_response_model.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';

void main() {
  group('AuthResponseModel', () {
    final tCreatedAt = DateTime.parse('2026-09-26T12:00:00.000Z');
    final tUser = UserModel(
      id: 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
      email: 'student@example.com',
      emailVerified: false,
      createdAt: tCreatedAt,
    );

    const tTokens = TokenModel(
      accessToken: 'access_jwt',
      refreshToken: 'refresh_jwt',
      expiresIn: 900,
    );

    final tAuthResponse = AuthResponseModel(
      user: tUser,
      tokens: tTokens,
    );

    test('should parse valid JSON containing user and tokens', () {
      final jsonMap = <String, dynamic>{
        'user': <String, dynamic>{
          'id': 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
          'email': 'student@example.com',
          'emailVerified': false,
          'createdAt': '2026-09-26T12:00:00.000Z',
        },
        'tokens': <String, dynamic>{
          'accessToken': 'access_jwt',
          'refreshToken': 'refresh_jwt',
          'expiresIn': 900,
        },
      };

      final result = AuthResponseModel.fromJson(jsonMap);

      expect(result, equals(tAuthResponse));
      expect(result.user, equals(tUser));
      expect(result.tokens, equals(tTokens));
    });

    test('toJson should serialize AuthResponseModel correctly', () {
      final json = tAuthResponse.toJson();

      expect(json['user'], isA<Map<String, dynamic>>());
      expect(json['tokens'], isA<Map<String, dynamic>>());
      expect(
        (json['user'] as Map<String, dynamic>)['id'],
        'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
      );
      expect(
        (json['tokens'] as Map<String, dynamic>)['accessToken'],
        'access_jwt',
      );
    });

    test('two instances with same properties should be equal', () {
      final copy = AuthResponseModel(
        user: tUser,
        tokens: tTokens,
      );

      expect(copy, equals(tAuthResponse));
    });
  });
}

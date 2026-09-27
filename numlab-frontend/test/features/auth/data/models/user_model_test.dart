import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    final tCreatedAt = DateTime.parse('2026-09-26T12:00:00.000Z');
    final tLastLoginAt = DateTime.parse('2026-09-26T12:05:00.000Z');
    final tUpdatedAt = DateTime.parse('2026-09-26T12:05:00.000Z');

    final tUserFull = UserModel(
      id: 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
      email: 'student@example.com',
      emailVerified: true,
      createdAt: tCreatedAt,
      lastLoginAt: tLastLoginAt,
      updatedAt: tUpdatedAt,
    );

    final tUserMinimal = UserModel(
      id: 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
      email: 'student@example.com',
      emailVerified: false,
      createdAt: tCreatedAt,
    );

    test('should parse valid JSON with all fields present', () {
      final jsonMap = <String, dynamic>{
        'id': 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
        'email': 'student@example.com',
        'emailVerified': true,
        'createdAt': '2026-09-26T12:00:00.000Z',
        'lastLoginAt': '2026-09-26T12:05:00.000Z',
        'updatedAt': '2026-09-26T12:05:00.000Z',
      };

      final result = UserModel.fromJson(jsonMap);

      expect(result, equals(tUserFull));
      expect(result.id, 'c89b7b90-1c0b-46a2-9e5b-ecf720078021');
      expect(result.email, 'student@example.com');
      expect(result.emailVerified, isTrue);
      expect(result.createdAt, tCreatedAt);
      expect(result.lastLoginAt, tLastLoginAt);
      expect(result.updatedAt, tUpdatedAt);
    });

    test('should parse valid JSON with nullable fields absent or null', () {
      final jsonMap = <String, dynamic>{
        'id': 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
        'email': 'student@example.com',
        'createdAt': '2026-09-26T12:00:00.000Z',
      };

      final result = UserModel.fromJson(jsonMap);

      expect(result, equals(tUserMinimal));
      expect(result.emailVerified, isFalse);
      expect(result.lastLoginAt, isNull);
      expect(result.updatedAt, isNull);
    });

    test('fromResponseData should parse directly from data map', () {
      final dataMap = <String, dynamic>{
        'id': 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
        'email': 'student@example.com',
        'emailVerified': false,
        'createdAt': '2026-09-26T12:00:00.000Z',
      };

      final result = UserModel.fromResponseData(dataMap);

      expect(result, equals(tUserMinimal));
    });

    test(
      'fromResponseData should parse from nested user object if present',
      () {
        final wrappedDataMap = <String, dynamic>{
          'user': <String, dynamic>{
            'id': 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
            'email': 'student@example.com',
            'emailVerified': false,
            'createdAt': '2026-09-26T12:00:00.000Z',
          },
        };

        final result = UserModel.fromResponseData(wrappedDataMap);

        expect(result, equals(tUserMinimal));
      },
    );

    test('toJson should serialize UserModel correctly', () {
      final json = tUserFull.toJson();

      expect(json['id'], 'c89b7b90-1c0b-46a2-9e5b-ecf720078021');
      expect(json['email'], 'student@example.com');
      expect(json['emailVerified'], isTrue);
      expect(json['createdAt'], '2026-09-26T12:00:00.000Z');
      expect(json['lastLoginAt'], '2026-09-26T12:05:00.000Z');
      expect(json['updatedAt'], '2026-09-26T12:05:00.000Z');
    });

    test('two instances with same properties should be equal', () {
      final copy = UserModel(
        id: 'c89b7b90-1c0b-46a2-9e5b-ecf720078021',
        email: 'student@example.com',
        emailVerified: true,
        createdAt: tCreatedAt,
        lastLoginAt: tLastLoginAt,
        updatedAt: tUpdatedAt,
      );

      expect(copy, equals(tUserFull));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';

void main() {
  group('TokenModel', () {
    const tTokens = TokenModel(
      accessToken: 'sample_access_token_jwt',
      refreshToken: 'sample_refresh_token_jwt',
      expiresIn: 900,
    );

    test('should parse valid JSON correctly', () {
      final jsonMap = <String, dynamic>{
        'accessToken': 'sample_access_token_jwt',
        'refreshToken': 'sample_refresh_token_jwt',
        'expiresIn': 900,
      };

      final result = TokenModel.fromJson(jsonMap);

      expect(result, equals(tTokens));
      expect(result.accessToken, 'sample_access_token_jwt');
      expect(result.refreshToken, 'sample_refresh_token_jwt');
      expect(result.expiresIn, 900);
    });

    test('toJson should serialize TokenModel correctly', () {
      final json = tTokens.toJson();

      expect(json['accessToken'], 'sample_access_token_jwt');
      expect(json['refreshToken'], 'sample_refresh_token_jwt');
      expect(json['expiresIn'], 900);
    });

    test('two instances with same properties should be equal', () {
      const copy = TokenModel(
        accessToken: 'sample_access_token_jwt',
        refreshToken: 'sample_refresh_token_jwt',
        expiresIn: 900,
      );

      expect(copy, equals(tTokens));
    });
  });
}

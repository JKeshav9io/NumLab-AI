import 'package:numlab_frontend/features/auth/domain/entities/token.dart';

/// Immutable representation of the JWT token pair and expiration.
class TokenModel extends Token {
  const TokenModel({
    required super.accessToken,
    required super.refreshToken,
    required super.expiresIn,
  });

  /// Factory constructor to parse tokens from JSON map.
  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
    );
  }

  /// Constructs a [TokenModel] from a domain [Token] entity.
  factory TokenModel.fromEntity(Token token) {
    return TokenModel(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
      expiresIn: token.expiresIn,
    );
  }

  /// Converts this data model to a domain [Token] entity.
  Token toEntity() {
    return Token(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
    };
  }
}

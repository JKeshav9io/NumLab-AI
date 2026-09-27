import 'package:equatable/equatable.dart';

/// Domain entity representing JWT authentication tokens.
class Token extends Equatable {
  const Token({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  /// Short-lived JWT access token for authenticating API requests.
  final String accessToken;

  /// Long-lived opaque/JWT refresh token used to rotate expired access tokens.
  final String refreshToken;

  /// Expiration lifetime of the access token in seconds.
  final int expiresIn;

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresIn];
}

import 'package:numlab_frontend/features/auth/data/models/token_model.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';
import 'package:numlab_frontend/features/auth/domain/entities/auth_result.dart';

/// Combined authentication response holding the authenticated [user]
/// and issued token pair [tokens] for register and login flows.
class AuthResponseModel extends AuthResult {
  const AuthResponseModel({
    required UserModel user,
    required TokenModel tokens,
  }) : super(user: user, tokens: tokens);

  /// Factory constructor to parse register/login response data map.
  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>;
    final tokensJson = json['tokens'] as Map<String, dynamic>;

    return AuthResponseModel(
      user: UserModel.fromJson(userJson),
      tokens: TokenModel.fromJson(tokensJson),
    );
  }

  @override
  UserModel get user => super.user as UserModel;

  @override
  TokenModel get tokens => super.tokens as TokenModel;

  /// Converts this data model to a domain [AuthResult] entity.
  AuthResult toEntity() {
    return AuthResult(
      user: user.toEntity(),
      tokens: tokens.toEntity(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user': user.toJson(),
      'tokens': tokens.toJson(),
    };
  }
}

import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/features/auth/domain/entities/token.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';

/// Combined domain entity representing a successful authentication session.
class AuthResult extends Equatable {
  const AuthResult({
    required this.user,
    required this.tokens,
  });

  /// The authenticated user profile.
  final User user;

  /// The issued authentication token pair.
  final Token tokens;

  @override
  List<Object?> get props => [user, tokens];
}

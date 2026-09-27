import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/domain/repositories/auth_repository.dart';

/// Use case for logging out the single session associated with a refresh token.
class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  /// Revokes the current session's refresh token on the backend.
  Future<Either<Failure, void>> call({
    required String refreshToken,
  }) {
    return _repository.logout(
      refreshToken: refreshToken,
    );
  }
}

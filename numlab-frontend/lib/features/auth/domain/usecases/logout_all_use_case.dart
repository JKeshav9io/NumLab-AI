import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/domain/repositories/auth_repository.dart';

/// Use case for revoking all active sessions and refresh tokens across all devices.
class LogoutAllUseCase {
  const LogoutAllUseCase(this._repository);

  final AuthRepository _repository;

  /// Revokes all sessions for the authenticated user.
  Future<Either<Failure, void>> call({
    String? accessToken,
  }) {
    return _repository.logoutAll(
      accessToken: accessToken,
    );
  }
}

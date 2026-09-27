import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/domain/entities/token.dart';
import 'package:numlab_frontend/features/auth/domain/repositories/auth_repository.dart';

/// Use case for rotating an existing refresh token into a new token pair.
class RefreshTokenUseCase {
  const RefreshTokenUseCase(this._repository);

  final AuthRepository _repository;

  /// Executes token refresh and maps the result to a domain [Token] entity.
  Future<Either<Failure, Token>> call({
    required String refreshToken,
  }) async {
    final result = await _repository.refresh(
      refreshToken: refreshToken,
    );

    return result.map((tokenModel) => tokenModel.toEntity());
  }
}

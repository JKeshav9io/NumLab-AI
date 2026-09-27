import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/domain/repositories/auth_repository.dart';

/// Use case for fetching the profile of the currently authenticated user.
class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  /// Retrieves the current user profile and maps it to a domain [User] entity.
  Future<Either<Failure, User>> call({
    String? accessToken,
  }) async {
    final result = await _repository.getCurrentUser(
      accessToken: accessToken,
    );

    return result.map((userModel) => userModel.toEntity());
  }
}

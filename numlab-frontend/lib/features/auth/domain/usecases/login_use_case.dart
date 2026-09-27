import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/domain/entities/auth_result.dart';
import 'package:numlab_frontend/features/auth/domain/repositories/auth_repository.dart';

/// Use case for authenticating an existing user with email and password.
class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  /// Executes user login and maps the result to a domain [AuthResult] entity.
  Future<Either<Failure, AuthResult>> call({
    required String email,
    required String password,
  }) async {
    final result = await _repository.login(
      email: email,
      password: password,
    );

    return result.map((responseModel) => responseModel.toEntity());
  }
}

import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/domain/entities/auth_result.dart';
import 'package:numlab_frontend/features/auth/domain/repositories/auth_repository.dart';

/// Use case for registering a new user account with email and password.
class RegisterUseCase {
  const RegisterUseCase(this._repository);

  final AuthRepository _repository;

  /// Executes user registration and maps the result to a domain [AuthResult] entity.
  Future<Either<Failure, AuthResult>> call({
    required String email,
    required String password,
  }) async {
    final result = await _repository.register(
      email: email,
      password: password,
    );

    return result.map((responseModel) => responseModel.toEntity());
  }
}

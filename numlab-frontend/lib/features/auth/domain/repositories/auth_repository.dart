import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/data/models/auth_response_model.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';

/// Domain repository contract for authentication operations in NumLab AI.
abstract interface class AuthRepository {
  /// Registers a user and returns [AuthResponseModel] on success or [Failure].
  Future<Either<Failure, AuthResponseModel>> register({
    required String email,
    required String password,
  });

  /// Logs in a user and returns [AuthResponseModel] on success or [Failure].
  Future<Either<Failure, AuthResponseModel>> login({
    required String email,
    required String password,
  });

  /// Refreshes access and refresh tokens.
  Future<Either<Failure, TokenModel>> refresh({
    required String refreshToken,
  });

  /// Logs out the current session.
  Future<Either<Failure, void>> logout({
    required String refreshToken,
  });

  /// Logs out all sessions for the authenticated user.
  Future<Either<Failure, void>> logoutAll({
    String? accessToken,
  });

  /// Fetches the profile of the currently authenticated user.
  Future<Either<Failure, UserModel>> getCurrentUser({
    String? accessToken,
  });
}

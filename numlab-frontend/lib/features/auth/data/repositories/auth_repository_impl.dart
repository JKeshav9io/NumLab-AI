import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/error_mapper.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:numlab_frontend/features/auth/data/models/auth_response_model.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';
import 'package:numlab_frontend/features/auth/domain/repositories/auth_repository.dart';

/// Implementation of [AuthRepository] managing authentication data flow
/// and translating data-layer exceptions into domain [Failure] types.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, AuthResponseModel>> register({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remoteDataSource.register(
        email: email,
        password: password,
      );
      return Right(result);
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }

  @override
  Future<Either<Failure, AuthResponseModel>> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remoteDataSource.login(
        email: email,
        password: password,
      );
      return Right(result);
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }

  @override
  Future<Either<Failure, TokenModel>> refresh({
    required String refreshToken,
  }) async {
    try {
      final result = await _remoteDataSource.refresh(
        refreshToken: refreshToken,
      );
      return Right(result);
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }

  @override
  Future<Either<Failure, void>> logout({
    required String refreshToken,
  }) async {
    try {
      await _remoteDataSource.logout(
        refreshToken: refreshToken,
      );
      return const Right(null);
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }

  @override
  Future<Either<Failure, void>> logoutAll({
    String? accessToken,
  }) async {
    try {
      await _remoteDataSource.logoutAll(
        accessToken: accessToken,
      );
      return const Right(null);
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }

  @override
  Future<Either<Failure, UserModel>> getCurrentUser({
    String? accessToken,
  }) async {
    try {
      final result = await _remoteDataSource.getCurrentUser(
        accessToken: accessToken,
      );
      return Right(result);
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }
}

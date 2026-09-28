import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/error_mapper.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/solvers/data/datasources/solver_remote_data_source.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_config.dart';
import 'package:numlab_frontend/features/solvers/domain/repositories/solver_repository.dart';

/// Implementation of [SolverRepository] bridging the domain layer and network datasource.
///
/// Automatically retrieves authentication tokens when available for user history attribution,
/// supports anonymous solving, and maps all network/API exceptions to domain [Failure] instances.
class SolverRepositoryImpl implements SolverRepository {
  const SolverRepositoryImpl({
    required SolverRemoteDataSource remoteDataSource,
    SecureStorageService? secureStorageService,
  }) : _remoteDataSource = remoteDataSource,
       _secureStorageService = secureStorageService;

  final SolverRemoteDataSource _remoteDataSource;
  final SecureStorageService? _secureStorageService;

  @override
  Future<Either<Failure, SolverResult>> solve({
    required SolverMethodConfig config,
    required Map<String, dynamic> payload,
    String? accessToken,
  }) async {
    try {
      final token =
          accessToken ?? await _secureStorageService?.getAccessToken();
      final result = await _remoteDataSource.solve(
        config: config,
        payload: payload,
        accessToken: token,
      );
      return Right(result);
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }
}

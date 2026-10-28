import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/error_mapper.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/data/datasources/history_remote_data_source.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/history/domain/repositories/history_repository.dart';

/// Implementation of [HistoryRepository] bridging the domain layer and network datasource.
class HistoryRepositoryImpl implements HistoryRepository {
  const HistoryRepositoryImpl({
    required HistoryRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final HistoryRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, PaginatedHistory>> getHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final result = await _remoteDataSource.getHistory(
        limit: limit,
        offset: offset,
      );
      return Right(result.toEntity());
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }

  @override
  Future<Either<Failure, HistoryRun>> getRunById(String runId) async {
    try {
      final result = await _remoteDataSource.getRunById(runId);
      return Right(result.toEntity());
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }
}

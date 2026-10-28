import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_run.dart';
import 'package:numlab_frontend/features/history/domain/repositories/history_repository.dart';

/// Domain use case for retrieving a single historical calculation run by UUID.
class GetHistoryRunByIdUseCase {
  const GetHistoryRunByIdUseCase(this._repository);

  final HistoryRepository _repository;

  /// Fetches a historical solver run by its unique [runId].
  Future<Either<Failure, HistoryRun>> call(String runId) {
    return _repository.getRunById(runId);
  }
}

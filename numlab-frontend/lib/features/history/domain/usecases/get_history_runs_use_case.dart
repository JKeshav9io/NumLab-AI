import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/domain/entities/paginated_history.dart';
import 'package:numlab_frontend/features/history/domain/repositories/history_repository.dart';

/// Domain use case for retrieving a paginated page of historical calculation runs.
class GetHistoryRunsUseCase {
  const GetHistoryRunsUseCase(this._repository);

  final HistoryRepository _repository;

  /// Fetches historical solver runs for the authenticated user.
  Future<Either<Failure, PaginatedHistory>> call({
    int limit = 20,
    int offset = 0,
  }) {
    return _repository.getHistory(
      limit: limit,
      offset: offset,
    );
  }
}

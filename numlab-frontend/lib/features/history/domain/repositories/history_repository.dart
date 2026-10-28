import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';

/// Domain repository contract for historical solver run operations in NumLab AI.
abstract interface class HistoryRepository {
  /// Retrieves a paginated list of historical calculation runs.
  Future<Either<Failure, PaginatedHistory>> getHistory({
    int limit = 20,
    int offset = 0,
  });

  /// Retrieves the detailed calculation run with attached AI explanations by [runId].
  Future<Either<Failure, HistoryRun>> getRunById(String runId);
}

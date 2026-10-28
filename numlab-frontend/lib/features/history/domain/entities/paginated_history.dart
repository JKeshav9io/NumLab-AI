import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_run.dart';
import 'package:numlab_frontend/features/history/domain/entities/pagination.dart';

/// Domain entity representing a paginated list of historical calculation runs.
class PaginatedHistory extends Equatable {
  const PaginatedHistory({
    required this.runs,
    required this.pagination,
  });

  /// The list of historical runs in this page.
  final List<HistoryRun> runs;

  /// Associated pagination metadata.
  final Pagination pagination;

  @override
  List<Object?> get props => [runs, pagination];
}

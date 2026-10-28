import 'package:equatable/equatable.dart';

/// Sealed hierarchy of all history events handled by HistoryBloc.
sealed class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to request an initial page of calculation history.
final class HistoryLoadRequested extends HistoryEvent {
  const HistoryLoadRequested({
    this.limit = 20,
    this.offset = 0,
  });

  /// Maximum number of runs to fetch.
  final int limit;

  /// Starting offset.
  final int offset;

  @override
  List<Object?> get props => [limit, offset];
}

/// Dispatched to refresh calculation history from offset 0, replacing the current list.
final class HistoryRefreshRequested extends HistoryEvent {
  const HistoryRefreshRequested();
}

/// Dispatched to request the next page of calculation history based on current pagination.
final class HistoryLoadMoreRequested extends HistoryEvent {
  const HistoryLoadMoreRequested();
}

/// Dispatched to load detail for a single calculation run by its unique [runId].
final class HistoryRunRequested extends HistoryEvent {
  const HistoryRunRequested(this.runId);

  /// Unique UUID of the calculation run to fetch.
  final String runId;

  @override
  List<Object?> get props => [runId];
}

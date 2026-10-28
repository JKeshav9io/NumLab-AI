import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';

/// Sealed hierarchy of all history states emitted by HistoryBloc.
sealed class HistoryState extends Equatable {
  const HistoryState();

  /// Convenient accessor for any currently loaded history runs across all states.
  List<HistoryRun> get currentRuns => switch (this) {
    HistoryLoaded(:final runs) => runs,
    HistoryLoadingMore(:final runs) => runs,
    HistoryRefreshing(:final runs) => runs,
    HistoryDetailLoading(:final runs) => runs,
    HistoryDetailLoaded(:final runs) => runs,
    HistoryError(:final runs) => runs,
    _ => const [],
  };

  /// Convenient accessor for the current pagination metadata, if any page has been loaded.
  Pagination? get currentPagination => switch (this) {
    HistoryLoaded(:final pagination) => pagination,
    HistoryLoadingMore(:final pagination) => pagination,
    HistoryRefreshing(:final pagination) => pagination,
    HistoryDetailLoading(:final pagination) => pagination,
    HistoryDetailLoaded(:final pagination) => pagination,
    HistoryError(:final pagination) => pagination,
    _ => null,
  };

  @override
  List<Object?> get props => [];
}

/// Initial state before any history fetch has begun.
final class HistoryInitial extends HistoryState {
  const HistoryInitial();
}

/// State emitted while the initial history page is being fetched.
final class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

/// State representing successfully loaded calculation runs and pagination metadata.
final class HistoryLoaded extends HistoryState {
  const HistoryLoaded({
    required this.runs,
    required this.pagination,
    this.selectedRun,
  });

  /// The list of loaded calculation runs.
  final List<HistoryRun> runs;

  /// Associated pagination metadata.
  final Pagination pagination;

  /// Optional active run detail if selected from the list.
  final HistoryRun? selectedRun;

  @override
  List<Object?> get props => [runs, pagination, selectedRun];
}

/// State emitted while fetching subsequent paginated records, keeping existing runs visible.
final class HistoryLoadingMore extends HistoryState {
  const HistoryLoadingMore({
    required this.runs,
    required this.pagination,
  });

  /// The currently loaded runs before the next page arrives.
  final List<HistoryRun> runs;

  /// Active pagination metadata.
  final Pagination pagination;

  @override
  List<Object?> get props => [runs, pagination];
}

/// State emitted while refreshing history from offset 0, preserving existing loaded runs.
final class HistoryRefreshing extends HistoryState {
  const HistoryRefreshing({
    required this.runs,
    this.pagination,
  });

  /// Existing runs maintained during the refresh request.
  final List<HistoryRun> runs;

  /// Existing pagination metadata.
  final Pagination? pagination;

  @override
  List<Object?> get props => [runs, pagination];
}

/// State emitted while fetching full detail for a specific historical calculation run.
final class HistoryDetailLoading extends HistoryState {
  const HistoryDetailLoading({
    required this.runId,
    this.runs = const [],
    this.pagination,
  });

  /// Unique UUID of the run being fetched.
  final String runId;

  /// Maintained list of historical runs.
  final List<HistoryRun> runs;

  /// Maintained pagination metadata.
  final Pagination? pagination;

  @override
  List<Object?> get props => [runId, runs, pagination];
}

/// State representing a successfully fetched single history run detail.
final class HistoryDetailLoaded extends HistoryState {
  const HistoryDetailLoaded({
    required this.run,
    this.runs = const [],
    this.pagination,
  });

  /// The fully hydrated historical run entity (with explanations).
  final HistoryRun run;

  /// Maintained list of historical runs.
  final List<HistoryRun> runs;

  /// Maintained pagination metadata.
  final Pagination? pagination;

  @override
  List<Object?> get props => [run, runs, pagination];
}

/// State representing a failure in history operations.
final class HistoryError extends HistoryState {
  const HistoryError({
    required this.failure,
    this.runs = const [],
    this.pagination,
  });

  /// The domain failure explaining the error.
  final Failure failure;

  /// Maintained runs to avoid throwing away loaded content on non-fatal/pagination failures.
  final List<HistoryRun> runs;

  /// Maintained pagination metadata.
  final Pagination? pagination;

  /// Convenience accessor for user-facing error message.
  String get message => failure.message;

  @override
  List<Object?> get props => [failure, runs, pagination];
}

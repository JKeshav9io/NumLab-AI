import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/features/history/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/history_event.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/history_state.dart';

/// BLoC managing calculation run history, offset pagination, refresh, and detail loading.
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  HistoryBloc({
    required GetHistoryRunsUseCase getHistoryRunsUseCase,
    required GetHistoryRunByIdUseCase getHistoryRunByIdUseCase,
  }) : _getHistoryRunsUseCase = getHistoryRunsUseCase,
       _getHistoryRunByIdUseCase = getHistoryRunByIdUseCase,
       super(const HistoryInitial()) {
    on<HistoryLoadRequested>(_onLoadRequested);
    on<HistoryRefreshRequested>(_onRefreshRequested);
    on<HistoryLoadMoreRequested>(_onLoadMoreRequested);
    on<HistoryRunRequested>(_onRunRequested);
  }

  final GetHistoryRunsUseCase _getHistoryRunsUseCase;
  final GetHistoryRunByIdUseCase _getHistoryRunByIdUseCase;

  Future<void> _onLoadRequested(
    HistoryLoadRequested event,
    Emitter<HistoryState> emit,
  ) async {
    if (state is HistoryLoading) {
      return;
    }

    emit(const HistoryLoading());

    final result = await _getHistoryRunsUseCase(
      limit: event.limit,
      offset: event.offset,
    );

    if (state is! HistoryLoading) {
      return;
    }

    result.fold(
      (failure) => emit(HistoryError(failure: failure)),
      (paginatedHistory) => emit(
        HistoryLoaded(
          runs: paginatedHistory.runs,
          pagination: paginatedHistory.pagination,
        ),
      ),
    );
  }

  Future<void> _onRefreshRequested(
    HistoryRefreshRequested event,
    Emitter<HistoryState> emit,
  ) async {
    if (state is HistoryLoading || state is HistoryRefreshing) {
      return;
    }

    final existingRuns = state.currentRuns;
    final existingPagination = state.currentPagination;

    if (existingRuns.isNotEmpty) {
      emit(
        HistoryRefreshing(
          runs: existingRuns,
          pagination: existingPagination,
        ),
      );
    } else {
      emit(const HistoryLoading());
    }

    final limit = existingPagination?.limit ?? 20;
    final result = await _getHistoryRunsUseCase(
      limit: limit,
    );

    if (state is! HistoryRefreshing && state is! HistoryLoading) {
      return;
    }

    result.fold(
      (failure) => emit(
        HistoryError(
          failure: failure,
          runs: existingRuns,
          pagination: existingPagination,
        ),
      ),
      (paginatedHistory) => emit(
        HistoryLoaded(
          runs: paginatedHistory.runs,
          pagination: paginatedHistory.pagination,
        ),
      ),
    );
  }

  Future<void> _onLoadMoreRequested(
    HistoryLoadMoreRequested event,
    Emitter<HistoryState> emit,
  ) async {
    if (state is HistoryLoadingMore ||
        state is HistoryLoading ||
        state is HistoryRefreshing) {
      return;
    }

    final pagination = state.currentPagination;
    if (pagination == null || !pagination.hasMore) {
      return;
    }

    final existingRuns = state.currentRuns;
    final nextOffset = pagination.offset + pagination.limit;

    emit(
      HistoryLoadingMore(
        runs: existingRuns,
        pagination: pagination,
      ),
    );

    final result = await _getHistoryRunsUseCase(
      limit: pagination.limit,
      offset: nextOffset,
    );

    if (state is! HistoryLoadingMore) {
      return;
    }

    result.fold(
      (failure) => emit(
        HistoryError(
          failure: failure,
          runs: existingRuns,
          pagination: pagination,
        ),
      ),
      (paginatedHistory) {
        final existingIds = existingRuns.map((r) => r.id).toSet();
        final newUniqueRuns = paginatedHistory.runs
            .where((r) => !existingIds.contains(r.id))
            .toList(growable: false);
        final combinedRuns = [...existingRuns, ...newUniqueRuns];

        emit(
          HistoryLoaded(
            runs: combinedRuns,
            pagination: paginatedHistory.pagination,
          ),
        );
      },
    );
  }

  Future<void> _onRunRequested(
    HistoryRunRequested event,
    Emitter<HistoryState> emit,
  ) async {
    if (event.runId.trim().isEmpty) {
      return;
    }

    if (state is HistoryDetailLoading &&
        (state as HistoryDetailLoading).runId == event.runId) {
      return;
    }

    final existingRuns = state.currentRuns;
    final existingPagination = state.currentPagination;

    emit(
      HistoryDetailLoading(
        runId: event.runId,
        runs: existingRuns,
        pagination: existingPagination,
      ),
    );

    final result = await _getHistoryRunByIdUseCase(event.runId);

    if (state is! HistoryDetailLoading ||
        (state as HistoryDetailLoading).runId != event.runId) {
      return;
    }

    result.fold(
      (failure) => emit(
        HistoryError(
          failure: failure,
          runs: existingRuns,
          pagination: existingPagination,
        ),
      ),
      (run) {
        final updatedRuns = existingRuns.any((r) => r.id == run.id)
            ? existingRuns
                  .map((r) => r.id == run.id ? run : r)
                  .toList(growable: false)
            : existingRuns;

        emit(
          HistoryDetailLoaded(
            run: run,
            runs: updatedRuns,
            pagination: existingPagination,
          ),
        );
      },
    );
  }
}

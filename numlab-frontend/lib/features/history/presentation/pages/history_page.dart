import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/presentation/widgets/history_empty_state.dart';
import 'package:numlab_frontend/features/history/presentation/widgets/history_list.dart';
import 'package:numlab_frontend/injection_container.dart';

/// Minimal functional History page displaying authenticated calculation runs,
/// with pull-to-refresh and pagination support.
class HistoryPage extends StatelessWidget {
  const HistoryPage({
    this.bloc,
    this.onRunTap,
    super.key,
  });

  /// Optional pre-configured BLoC instance (e.g. for testing).
  final HistoryBloc? bloc;

  /// Optional item tap handler override (e.g. for testing).
  final void Function(String runId)? onRunTap;

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<HistoryBloc>.value(
        value: bloc!,
        child: _HistoryPageView(onRunTap: onRunTap),
      );
    }

    if (sl.isRegistered<HistoryBloc>()) {
      return BlocProvider<HistoryBloc>(
        create: (_) => sl<HistoryBloc>()..add(const HistoryLoadRequested()),
        child: _HistoryPageView(onRunTap: onRunTap),
      );
    }

    // Fallback if GetIt is uninitialized in standalone router tests
    return const Scaffold(
      key: Key('history_screen'),
      body: Center(child: Text('History Screen')),
    );
  }
}

class _HistoryPageView extends StatefulWidget {
  const _HistoryPageView({this.onRunTap});

  final void Function(String runId)? onRunTap;

  @override
  State<_HistoryPageView> createState() => _HistoryPageViewState();
}

class _HistoryPageViewState extends State<_HistoryPageView> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<HistoryBloc>();
    if (bloc.state is HistoryInitial) {
      bloc.add(const HistoryLoadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('history_screen'),
      appBar: AppBar(
        title: const Text('Calculation History'),
      ),
      body: SafeArea(
        child: BlocBuilder<HistoryBloc, HistoryState>(
          builder: (context, state) {
            // 1. Initial / Loading state
            if (state is HistoryLoading || state is HistoryInitial) {
              return const Center(
                child: CircularProgressIndicator(
                  key: Key('history_loading_indicator'),
                ),
              );
            }

            // 2. Fatal / Initial Error state (no runs to display)
            if (state is HistoryError && state.runs.isEmpty) {
              return Center(
                key: const Key('history_error_view'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        state.message,
                        key: const Key('history_error_message'),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton.icon(
                        key: const Key('history_retry_button'),
                        onPressed: () {
                          context.read<HistoryBloc>().add(
                            const HistoryLoadRequested(),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 3. Empty State (no runs returned)
            if (state.currentRuns.isEmpty) {
              return RefreshIndicator(
                key: const Key('history_empty_refresh_indicator'),
                onRefresh: () async {
                  context.read<HistoryBloc>().add(
                    const HistoryRefreshRequested(),
                  );
                },
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: const HistoryEmptyState(),
                    ),
                  ),
                ),
              );
            }

            // 4. Populated List with Pagination and Refresh
            return HistoryList(
              runs: state.currentRuns,
              isLoadingMore: state is HistoryLoadingMore,
              hasMore: state.currentPagination?.hasMore ?? false,
              loadMoreError: state is HistoryError ? state.message : null,
              onRefresh: () async {
                context.read<HistoryBloc>().add(
                  const HistoryRefreshRequested(),
                );
              },
              onLoadMore: () {
                context.read<HistoryBloc>().add(
                  const HistoryLoadMoreRequested(),
                );
              },
              onRunTap: (runId) {
                if (widget.onRunTap != null) {
                  widget.onRunTap!(runId);
                  return;
                }
                context.read<HistoryBloc>().add(
                  HistoryRunRequested(runId),
                );
                final router = GoRouter.maybeOf(context);
                if (router != null) {
                  context.go(AppRoutes.historyDetail(runId));
                }
              },
              onRetryLoadMore: () {
                context.read<HistoryBloc>().add(
                  const HistoryLoadMoreRequested(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

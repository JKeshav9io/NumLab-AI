import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_run.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_explanation.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_explanation_view.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_result_view.dart';
import 'package:numlab_frontend/injection_container.dart';

/// Screen displaying the complete result and execution details of a historical calculation.
///
/// Features:
/// - Reuses the existing [SolverResultView] presentation component.
/// - Fetches full historical run payload using [HistoryBloc].
/// - Converts the historical run entity into a domain [SolverResult].
/// - Retains persisted graph data and attached AI pedagogical explanations.
/// - Provides standard loading, error with retry, and back navigation.
class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({
    required this.runId,
    this.bloc,
    super.key,
  });

  /// Unique UUID of the historical calculation run.
  final String runId;

  /// Optional pre-configured BLoC instance (e.g. for testing).
  final HistoryBloc? bloc;

  static void _navigateBack(BuildContext context) {
    if (GoRouter.maybeOf(context)?.canPop() ?? Navigator.canPop(context)) {
      if (GoRouter.maybeOf(context) != null) {
        context.pop();
      } else {
        Navigator.of(context).pop();
      }
    } else {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        context.go(AppRoutes.history);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<HistoryBloc>.value(
        value: bloc!,
        child: _HistoryDetailPageView(runId: runId),
      );
    }

    if (sl.isRegistered<HistoryBloc>()) {
      return BlocProvider<HistoryBloc>(
        create: (_) => sl<HistoryBloc>(),
        child: _HistoryDetailPageView(runId: runId),
      );
    }

    // Fallback if GetIt is uninitialized in standalone router tests
    return Scaffold(
      key: const Key('history_detail_screen'),
      appBar: AppBar(
        title: const Text('Calculation Detail'),
        leading: IconButton(
          key: const Key('history_detail_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _navigateBack(context),
        ),
      ),
      body: PopScope(
        canPop:
            GoRouter.maybeOf(context)?.canPop() ?? Navigator.canPop(context),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              context.go(AppRoutes.history);
            }
          }
        },
        child: const Center(
          child: Text('History Detail Screen'),
        ),
      ),
    );
  }
}

class _HistoryDetailPageView extends StatefulWidget {
  const _HistoryDetailPageView({required this.runId});

  final String runId;

  @override
  State<_HistoryDetailPageView> createState() => _HistoryDetailPageViewState();
}

class _HistoryDetailPageViewState extends State<_HistoryDetailPageView> {
  @override
  void initState() {
    super.initState();
    _checkAndFetch();
  }

  @override
  void didUpdateWidget(covariant _HistoryDetailPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runId != widget.runId) {
      _checkAndFetch();
    }
  }

  void _checkAndFetch() {
    if (widget.runId.trim().isEmpty) return;

    final bloc = context.read<HistoryBloc>();
    final state = bloc.state;

    final isAlreadyLoaded =
        state is HistoryDetailLoaded && state.run.id == widget.runId;
    final isAlreadyLoading =
        state is HistoryDetailLoading && state.runId == widget.runId;

    if (!isAlreadyLoaded && !isAlreadyLoading) {
      bloc.add(HistoryRunRequested(widget.runId));
    }
  }

  Widget _buildRunResult(HistoryRun run) {
    final result = run.toSolverResult();
    final original = run.outputPayload['explanation'];
    // The legacy conversion uses attached AI text only when deterministic
    // explanation text is absent. Preserve both when the API supplies both.
    final hasOriginal =
        original is Map || (original is String && original.isNotEmpty);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SolverResultView(
            key: const Key('history_detail_solver_result_view'),
            result: result,
          ),
          if (hasOriginal && run.aiExplanations.isNotEmpty)
            SolverExplanationView(
              key: const Key('history_saved_ai_explanation'),
              title: 'Saved AI Explanation',
              explanation: SolverExplanation(
                summary: run.aiExplanations.first.responseText,
                steps: const [],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('history_detail_screen'),
      appBar: AppBar(
        title: const Text('Calculation Detail'),
        leading: IconButton(
          key: const Key('history_detail_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => HistoryDetailPage._navigateBack(context),
        ),
      ),
      body: PopScope(
        canPop:
            GoRouter.maybeOf(context)?.canPop() ?? Navigator.canPop(context),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              context.go(AppRoutes.history);
            }
          }
        },
        child: SafeArea(
          child: BlocBuilder<HistoryBloc, HistoryState>(
            builder: (context, state) {
              // 0. Invalid run ID guard
              if (widget.runId.trim().isEmpty) {
                return Center(
                  key: const Key('history_detail_invalid_id_view'),
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
                        const Text(
                          'Invalid calculation ID.',
                          key: Key('history_detail_invalid_id_message'),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton.icon(
                          key: const Key(
                            'history_detail_back_to_history_button',
                          ),
                          onPressed: () =>
                              HistoryDetailPage._navigateBack(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to History'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 1. Loading state specifically for this run
              if (state is HistoryDetailLoading &&
                  state.runId == widget.runId) {
                return const Center(
                  child: CircularProgressIndicator(
                    key: Key('history_detail_loading_indicator'),
                  ),
                );
              }

              // 2. Success state: run detail loaded for this runId
              if (state is HistoryDetailLoaded &&
                  state.run.id == widget.runId) {
                return _buildRunResult(state.run);
              }

              // 3. Fallback success state if selectedRun matches
              if (state is HistoryLoaded &&
                  state.selectedRun != null &&
                  state.selectedRun!.id == widget.runId) {
                return _buildRunResult(state.selectedRun!);
              }

              // 4. Error state
              if (state is HistoryError) {
                return Center(
                  key: const Key('history_detail_error_view'),
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
                          key: const Key('history_detail_error_message'),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton.icon(
                          key: const Key('history_detail_retry_button'),
                          onPressed: () {
                            context.read<HistoryBloc>().add(
                              HistoryRunRequested(widget.runId),
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

              // Default fallback: initial loading indicator
              return const Center(
                child: CircularProgressIndicator(
                  key: Key('history_detail_loading_indicator'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

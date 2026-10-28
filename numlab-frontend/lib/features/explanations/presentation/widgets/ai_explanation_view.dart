import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/explanations/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/explanations/presentation/widgets/explanation_content.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/injection_container.dart';

/// Minimal functional component displaying on-demand AI pedagogical explanations
/// for a completed [SolverResult].
///
/// Supports Idle, Loading, Success, and Failure/Retry states with duplicate-tap prevention
/// and stale explanation avoidance.
class AiExplanationView extends StatefulWidget {
  const AiExplanationView({
    required this.result,
    this.explanationBloc,
    this.focus = 'steps',
    this.includeGraphSummary,
    super.key = const Key('solver_ai_explanation_section'),
  });

  /// The solver result to explain.
  final SolverResult result;

  /// Optional BLoC override (e.g. for testing).
  final ExplanationBloc? explanationBloc;

  /// Focus mode for the AI explanation ('summary', 'steps', 'warnings', 'lab-report').
  final String focus;

  /// Whether to include graphical trends in explanation.
  final bool? includeGraphSummary;

  @override
  State<AiExplanationView> createState() => _AiExplanationViewState();
}

class _AiExplanationViewState extends State<AiExplanationView> {
  ExplanationBloc? _createdBloc;

  ExplanationBloc? _resolveBloc(BuildContext context) {
    if (widget.explanationBloc != null) {
      return widget.explanationBloc;
    }
    try {
      return context.read<ExplanationBloc>();
    } on Exception catch (_) {
      if (sl.isRegistered<ExplanationBloc>()) {
        return _createdBloc ??= sl<ExplanationBloc>();
      }
      return null;
    }
  }

  @override
  void didUpdateWidget(AiExplanationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Prevent displaying stale explanation when solver result changes
    if (oldWidget.result != widget.result) {
      final bloc = _resolveBloc(context);
      bloc?.add(const ExplanationReset());
    }
  }

  @override
  void dispose() {
    unawaited(_createdBloc?.close());
    super.dispose();
  }

  void _requestExplanation(ExplanationBloc bloc) {
    bloc.add(
      ExplanationRequested(
        solverResult: widget.result,
        focus: widget.focus,
        includeGraphSummary: widget.includeGraphSummary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = _resolveBloc(context);

    if (bloc == null) {
      return _buildContainer(
        context,
        child: _buildIdleState(context, null),
      );
    }

    return BlocBuilder<ExplanationBloc, ExplanationState>(
      bloc: bloc,
      builder: (context, state) {
        return _buildContainer(
          context,
          cached: state is ExplanationSuccess && state.explanation.cached,
          fresh:
              state is ExplanationSuccess &&
              state.explanation.cacheStatus == false,
          child: switch (state) {
            ExplanationInitial() => _buildIdleState(context, bloc),
            ExplanationLoading(:final isSlow) => _buildLoadingState(
              context,
              isSlow: isSlow,
            ),
            ExplanationSuccess(:final explanation) => _buildSuccessState(
              context,
              bloc,
              explanation.explanation,
              explanation.focus,
              explanation.model,
            ),
            ExplanationFailure() => _buildFailureState(
              context,
              bloc,
              state,
            ),
          },
        );
      },
    );
  }

  Widget _buildContainer(
    BuildContext context, {
    required Widget child,
    bool cached = false,
    bool fresh = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: const Key('solver_ai_explanation_container'),
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'AI Explanation',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (cached || fresh)
                Chip(
                  key: Key(
                    cached
                        ? 'explanation_cached_chip'
                        : 'explanation_fresh_chip',
                  ),
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    cached ? 'Cached' : 'Fresh',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _buildIdleState(BuildContext context, ExplanationBloc? bloc) {
    return FilledButton.icon(
      key: const Key('explain_with_ai_button'),
      onPressed: bloc != null ? () => _requestExplanation(bloc) : null,
      icon: const Icon(Icons.psychology_outlined, size: 18),
      label: const Text('Explain with AI'),
    );
  }

  Widget _buildLoadingState(BuildContext context, {required bool isSlow}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              key: Key('explanation_loading_indicator'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Generating AI explanation...',
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
        if (isSlow) ...[
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'The AI is taking longer to respond. Please keep waiting.',
            key: Key('explanation_slow_message'),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        FilledButton.icon(
          key: const Key('explain_with_ai_button_disabled'),
          onPressed: null,
          icon: const Icon(Icons.hourglass_empty, size: 18),
          label: const Text('Explain with AI'),
        ),
      ],
    );
  }

  Widget _buildSuccessState(
    BuildContext context,
    ExplanationBloc bloc,
    String explanationText,
    String focus,
    String model,
  ) {
    return Column(
      key: const Key('explanation_success_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExplanationContent(
          content: explanationText,
          key: const Key('solver_ai_explanation_text'),
        ),
        if (explanationText.trim().isEmpty)
          OutlinedButton.icon(
            key: const Key('explanation_retry_button'),
            onPressed: () => _requestExplanation(bloc),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        if (focus.isNotEmpty || model.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (focus.isNotEmpty)
                Chip(
                  key: const Key('explanation_focus_chip'),
                  visualDensity: VisualDensity.compact,
                  label: Text('Focus: $focus'),
                ),
              if (model.isNotEmpty)
                Chip(
                  key: const Key('explanation_model_chip'),
                  visualDensity: VisualDensity.compact,
                  label: Text('Model: $model'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFailureState(
    BuildContext context,
    ExplanationBloc bloc,
    ExplanationFailure failure,
  ) {
    return Column(
      key: const Key('explanation_failure_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                failure.message,
                key: const Key('explanation_error_message'),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('explanation_retry_button'),
          onPressed: () => _requestExplanation(bloc),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
        if (failure.isRateLimit) ...[
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'AI explanation limit reached.',
            key: Key('explanation_rate_limit_message'),
          ),
          Text(
            failure.retryAfterSeconds != null
                ? 'The server asked you to wait ${failure.retryAfterSeconds} seconds before retrying.'
                : 'Please wait before retrying. No retry time was provided.',
            key: const Key('explanation_cooldown_message'),
          ),
        ],
      ],
    );
  }
}

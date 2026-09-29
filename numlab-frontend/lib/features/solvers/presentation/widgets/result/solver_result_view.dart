import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/charts.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_explanation_view.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_final_answer_view.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_iterations_view.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_warnings_view.dart';

/// Reusable solver result display component.
///
/// Features:
/// - Generic presentation of calculation results across all 27 solvers.
/// - Status and convergence indicator.
/// - Primary mathematical metric callouts (root, scalar value, solution vector, error).
/// - Comprehensive `finalAnswer` key-value breakdown for arbitrary shapes.
/// - Interactive 2D graph visualization with RepaintBoundary isolation.
/// - Step-by-step mathematical/AI explanation.
/// - Tabular iteration steps breakdown.
/// - Graph-data availability indicator.
/// - Non-fatal solver warning alerts.
/// - Modular design suitable for direct reuse in History views.
class SolverResultView extends StatelessWidget {
  const SolverResultView({
    required this.result,
    super.key,
  });

  final SolverResult result;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConverged = result.isConverged;

    return Card(
      key: const Key('solver_result_card'),
      color: isDark
          ? (isConverged
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.darkCard)
          : (isConverged
                ? AppColors.success.withValues(alpha: 0.06)
                : AppColors.lightCard),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(
          color: isConverged
              ? AppColors.success.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          key: const Key('solver_result_view'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Title
            Row(
              children: [
                Icon(
                  isConverged ? Icons.check_circle_outline : Icons.info_outline,
                  color: isConverged ? AppColors.success : AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Calculation Result',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isConverged ? AppColors.success : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Method: ${result.method}',
              key: const Key('solver_result_display'),
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 2. Status & Metric Chips
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                Chip(
                  key: const Key('solver_result_status'),
                  avatar: Icon(
                    isConverged ? Icons.check : Icons.circle,
                    size: 14,
                    color: isConverged ? AppColors.success : AppColors.warning,
                  ),
                  label: Text(
                    result.status != null
                        ? 'Status: ${result.status}'
                        : (isConverged
                              ? 'Status: Converged'
                              : 'Status: Complete'),
                  ),
                ),
                Chip(
                  key: const Key('solver_result_time'),
                  avatar: const Icon(Icons.timer_outlined, size: 14),
                  label: Text('Time: ${result.executionTimeMs} ms'),
                ),
                if (result.iterationsCount != null)
                  Chip(
                    key: const Key('solver_result_iterations'),
                    avatar: const Icon(Icons.repeat, size: 14),
                    label: Text('Iterations: ${result.iterationsCount}'),
                  ),
                if (result.hasGraphData)
                  const Chip(
                    key: Key('solver_graph_available_badge'),
                    avatar: Icon(
                      Icons.show_chart,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    label: Text('Graph Data Available'),
                  ),
              ],
            ),
            const Divider(height: 24),

            // 3. Warnings Alert
            if (result.hasWarnings)
              SolverWarningsView(warnings: result.warnings),

            // 4. Primary Mathematical Highlight Callouts
            if (result.root != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  'Root: ${result.root}',
                  key: const Key('solver_result_root'),
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

            if (result.resultValue != null && result.resultValue != result.root)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  'Value: ${result.resultValue}',
                  key: const Key('solver_result_value'),
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

            if (result.solutionVector != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  'Solution: ${SolverFinalAnswerView.formatValue(result.solutionVector)}',
                  key: const Key('solver_result_solution'),
                  style: AppTypography.codeMono.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

            if (result.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  'Estimated Error: ${result.error}',
                  key: const Key('solver_result_error'),
                  style: AppTypography.bodyMedium,
                ),
              ),

            // 5. Generic Final Answer Key-Value Breakdown
            SolverFinalAnswerView(finalAnswer: result.finalAnswer),

            // 6. Interactive Graph Visualization
            if (result.hasGraphData)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: SolverChartView(
                  graphData: result.typedGraphData,
                  rawGraphData: result.graphData,
                  title: '${result.method} Graph',
                ),
              ),

            // 7. Iteration History Table
            if (result.hasIterations)
              SolverIterationsView(iterations: result.iterations),

            // 8. Step-by-Step Explanation
            if (result.hasExplanation)
              SolverExplanationView(explanation: result.explanation!),

            // 8. Metadata Footer (Request ID & Timestamp)
            if (result.requestId != null || result.timestamp != null)
              Padding(
                key: const Key('solver_result_meta'),
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (result.requestId != null)
                      Expanded(
                        child: Text(
                          'Req: ${result.requestId}',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (result.requestId != null && result.timestamp != null)
                      const SizedBox(width: AppSpacing.sm),
                    if (result.timestamp != null)
                      Flexible(
                        child: Text(
                          result.timestamp!,
                          textAlign: TextAlign.end,
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

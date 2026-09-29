import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_graph_data_model.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/curve_chart_renderer.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/differentiation_chart_renderer.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/interpolation_chart_renderer.dart';

/// Master chart orchestrator widget that inspects typed [SolverGraphData] (or raw backend JSON)
/// and delegates rendering to the appropriate specialized chart renderer.
///
/// Features:
/// - Isolated from BLoC layer (pure presentation widget driven by data).
/// - Enclosed in a [RepaintBoundary] to ensure chart interactions and repaints do not affect parent views.
/// - Renders chart container, title header, coordinate bounds summary, and interactive series legend.
class SolverChartView extends StatelessWidget {
  const SolverChartView({
    this.graphData,
    this.rawGraphData,
    this.title = 'Graph Visualization',
    this.subtitle,
    this.lineColor,
    this.showAreaFill = false,
    this.height = 220,
    super.key,
  });

  /// Strongly-typed graph data entity.
  final SolverGraphData? graphData;

  /// Optional fallback raw backend JSON (parsed safely via [SolverGraphDataModel]).
  final dynamic rawGraphData;

  /// Custom header title for the chart card.
  final String title;

  /// Optional subtitle or method descriptor.
  final String? subtitle;

  /// Optional custom line color.
  final Color? lineColor;

  /// Whether to render area shading below curve lines.
  final bool showAreaFill;

  /// Height constraint for the chart canvas.
  final double height;

  @override
  Widget build(BuildContext context) {
    // Resolve typed graph data from either direct entity or raw JSON
    final data = graphData ?? SolverGraphDataModel.fromDynamic(rawGraphData);

    if (data == null || data.isEmpty) {
      return const SizedBox(
        key: Key('solver_chart_empty_placeholder'),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      key: const Key('solver_chart_card'),
      elevation: 0,
      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          key: const Key('solver_chart_view'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Chart Header
            Row(
              children: [
                const Icon(
                  Icons.show_chart,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    key: const Key('solver_chart_title'),
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildTypeBadge(data),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                key: const Key('solver_chart_subtitle'),
                style: AppTypography.labelSmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),

            // 2. Chart Rendering Area with RepaintBoundary
            RepaintBoundary(
              key: const Key('solver_chart_view_repaint_boundary'),
              child: _buildRenderer(data),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 3. Legend / Series Metadata
            _buildLegend(context, data),
          ],
        ),
      ),
    );
  }

  Widget _buildRenderer(SolverGraphData data) {
    switch (data) {
      case CurveGraphData():
        return CurveChartRenderer(
          data: data,
          lineColor: lineColor,
          showAreaFill: showAreaFill,
          height: height,
        );
      case InterpolationGraphData():
        return InterpolationChartRenderer(
          data: data,
          height: height,
        );
      case DifferentiationGraphData():
        return DifferentiationChartRenderer(
          data: data,
          height: height,
        );
    }
  }

  Widget _buildTypeBadge(SolverGraphData data) {
    String label;
    Color color;

    switch (data) {
      case CurveGraphData():
        label = 'Curve Plot';
        color = AppColors.primary;
      case InterpolationGraphData():
        label = 'Polynomial Fit';
        color = AppColors.accent;
      case DifferentiationGraphData():
        label = 'Stencil Plot';
        color = AppColors.secondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        key: const Key('solver_chart_type_badge'),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, SolverGraphData data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = AppTypography.labelSmall.copyWith(
      color: isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary,
      fontSize: 11,
    );

    switch (data) {
      case CurveGraphData():
        return Row(
          children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: lineColor ?? AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                data.label ?? 'Function f(x) / Trajectory',
                style: textStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${data.points.length} points',
              key: const Key('solver_chart_points_count'),
              style: textStyle,
            ),
          ],
        );

      case InterpolationGraphData():
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            if (data.sampledCurve.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Fitted Curve', style: textStyle),
                ],
              ),
            if (data.originalPoints.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Data Nodes (${data.originalPoints.length})',
                    style: textStyle,
                  ),
                ],
              ),
            if (data.predictedPoint != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    'Target (${data.predictedPoint!.x}, ${data.predictedPoint!.y})',
                    style: textStyle,
                  ),
                ],
              ),
          ],
        );

      case DifferentiationGraphData():
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            if (data.originalPoints.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('Tabular Points', style: textStyle),
                ],
              ),
            if (data.stencilPoints.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Stencil Nodes (${data.stencilPoints.length})',
                    style: textStyle,
                  ),
                ],
              ),
            if (data.derivativePoint != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('Derivative Point', style: textStyle),
                ],
              ),
          ],
        );
    }
  }
}

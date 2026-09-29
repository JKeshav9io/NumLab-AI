import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/chart_downsampler.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/chart_theme_adapter.dart';

/// Renders a continuous or discrete 2D curve from [CurveGraphData] using fl_chart.
///
/// Designed for:
/// - Root-Finding f(x) functions
/// - ODE trajectories (x_n, y_n)
/// - Numerical Integration integrands with area shading
/// - Function Finite Differentiation sampled curves
class CurveChartRenderer extends StatelessWidget {
  const CurveChartRenderer({
    required this.data,
    this.lineColor,
    this.showAreaFill = false,
    this.height = 220,
    super.key,
  });

  /// The domain curve data containing verified [CoordinatePoint] values.
  final CurveGraphData data;

  /// Optional custom line color (defaults to [AppColors.primary]).
  final Color? lineColor;

  /// Whether to render semi-transparent area shading below the curve.
  final bool showAreaFill;

  /// Height constraint for the chart canvas.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No curve points available for plotting',
            key: Key('curve_chart_empty_text'),
          ),
        ),
      );
    }

    final spots = ChartDownsampler.toOptimizedSpots(data.points);

    if (spots.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No valid coordinate points to plot',
            key: Key('curve_chart_invalid_text'),
          ),
        ),
      );
    }

    final color = lineColor ?? AppColors.primary;
    final isDense = spots.length > 50;

    // Calculate axis bounds with 8% padding to prevent clipping at boundaries
    var minX = data.minX;
    var maxX = data.maxX;
    var minY = data.minY;
    var maxY = data.maxY;

    if (minX == maxX) {
      minX -= 1.0;
      maxX += 1.0;
    }
    if (minY == maxY) {
      minY -= 1.0;
      maxY += 1.0;
    }

    final xSpan = (maxX - minX).abs();
    final ySpan = (maxY - minY).abs();

    final paddedMinX = minX - (xSpan * 0.05);
    final paddedMaxX = maxX + (xSpan * 0.05);
    final paddedMinY = minY - (ySpan * 0.08);
    final paddedMaxY = maxY + (ySpan * 0.08);

    final lineBarData = LineChartBarData(
      spots: spots,
      isCurved: spots.length > 2 && !isDense,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: spots.length <= 25,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 1.5,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: showAreaFill,
        color: color.withValues(alpha: 0.15),
      ),
    );

    return RepaintBoundary(
      key: const Key('curve_chart_repaint_boundary'),
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            lineTouchData: ChartThemeAdapter.buildTouchData(
              context,
              seriesNameResolver: (barIndex, spot) =>
                  data.label ?? 'Curve Point',
            ),
            gridData: ChartThemeAdapter.buildGridData(context),
            titlesData: ChartThemeAdapter.buildTitlesData(
              context,
              minX: paddedMinX,
              maxX: paddedMaxX,
              minY: paddedMinY,
              maxY: paddedMaxY,
            ),
            borderData: ChartThemeAdapter.buildBorderData(context),
            minX: paddedMinX,
            maxX: paddedMaxX,
            minY: paddedMinY,
            maxY: paddedMaxY,
            lineBarsData: [lineBarData],
          ),
        ),
      ),
    );
  }
}

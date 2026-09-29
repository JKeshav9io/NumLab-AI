import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/chart_downsampler.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/chart_theme_adapter.dart';

/// Renders tabular numerical differentiation data displaying:
/// 1. Original input tabular dataset points (scatter dots)
/// 2. Stencil evaluation points (highlighted stencil nodes)
/// 3. Evaluated derivative coordinate point (distinct target dot)
class DifferentiationChartRenderer extends StatelessWidget {
  const DifferentiationChartRenderer({
    required this.data,
    this.height = 220,
    super.key,
  });

  /// The domain differentiation graph data model.
  final DifferentiationGraphData data;

  /// Height constraint for the chart canvas.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No differentiation plot data available',
            key: Key('differentiation_chart_empty_text'),
          ),
        ),
      );
    }

    final originalSpots = ChartDownsampler.toOptimizedSpots(
      data.originalPoints,
    );

    final stencilSpots = data.stencilPoints
        .where((p) => p.isValid)
        .map((p) => FlSpot(p.x, p.y))
        .toList(growable: false);

    final derivativePoint = data.derivativePoint;
    final derivativeSpot = (derivativePoint != null && derivativePoint.isValid)
        ? FlSpot(derivativePoint.x, derivativePoint.y)
        : null;

    final lineBars = <LineChartBarData>[];
    final seriesNames = <String>[];

    // Original points line / scatter
    if (originalSpots.isNotEmpty) {
      seriesNames.add('Data Point');
      lineBars.add(
        LineChartBarData(
          spots: originalSpots,
          isCurved: originalSpots.length > 2,
          curveSmoothness: 0.2,
          color: AppColors.primary.withValues(alpha: 0.4),
          barWidth: 1.5,
          dotData: FlDotData(
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 3.5,
                  color: AppColors.primary,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                ),
          ),
        ),
      );
    }

    // Stencil points highlight
    if (stencilSpots.isNotEmpty) {
      seriesNames.add('Stencil Node');
      lineBars.add(
        LineChartBarData(
          spots: stencilSpots,
          barWidth: 0,
          dotData: FlDotData(
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 5.5,
                  color: AppColors.accent,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
          ),
        ),
      );
    }

    // Derivative point marker
    if (derivativeSpot != null) {
      seriesNames.add('Derivative Point');
      lineBars.add(
        LineChartBarData(
          spots: [derivativeSpot],
          barWidth: 0,
          dotData: FlDotData(
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 6.5,
                  color: AppColors.error,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
          ),
        ),
      );
    }

    if (lineBars.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No valid coordinate points to plot',
            key: Key('differentiation_chart_invalid_text'),
          ),
        ),
      );
    }

    // Calculate axis bounds with 8% padding
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

    final paddedMinX = minX - (xSpan * 0.06);
    final paddedMaxX = maxX + (xSpan * 0.06);
    final paddedMinY = minY - (ySpan * 0.08);
    final paddedMaxY = maxY + (ySpan * 0.08);

    return RepaintBoundary(
      key: const Key('differentiation_chart_repaint_boundary'),
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            lineTouchData: ChartThemeAdapter.buildTouchData(
              context,
              seriesNameResolver: (barIndex, spot) =>
                  (barIndex >= 0 && barIndex < seriesNames.length)
                  ? seriesNames[barIndex]
                  : 'Point',
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
            lineBarsData: lineBars,
          ),
        ),
      ),
    );
  }
}

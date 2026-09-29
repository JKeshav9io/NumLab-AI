import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/chart_downsampler.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/chart_theme_adapter.dart';

/// Renders multi-series interpolation graphs combining:
/// 1. Continuous fitted polynomial / spline curve (smooth line)
/// 2. Original input dataset nodes (prominent scatter dots)
/// 3. Evaluated target predicted point (accent highlight marker)
class InterpolationChartRenderer extends StatelessWidget {
  const InterpolationChartRenderer({
    required this.data,
    this.height = 220,
    super.key,
  });

  /// The domain interpolation graph data model.
  final InterpolationGraphData data;

  /// Height constraint for the chart canvas.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No interpolation plot data available',
            key: Key('interpolation_chart_empty_text'),
          ),
        ),
      );
    }

    // 1. Fitted curve series
    final curveSpots = ChartDownsampler.toOptimizedSpots(data.sampledCurve);

    // 2. Original dataset points series
    final originalSpots = data.originalPoints
        .where((p) => p.isValid)
        .map((p) => FlSpot(p.x, p.y))
        .toList(growable: false);

    // 3. Predicted target point series
    final predictedPoint = data.predictedPoint;
    final predictedSpot = (predictedPoint != null && predictedPoint.isValid)
        ? FlSpot(predictedPoint.x, predictedPoint.y)
        : null;

    final lineBars = <LineChartBarData>[];
    final seriesNames = <String>[];

    // Add continuous curve line
    if (curveSpots.isNotEmpty) {
      seriesNames.add('Fitted Curve');
      lineBars.add(
        LineChartBarData(
          spots: curveSpots,
          isCurved: curveSpots.length > 2 && curveSpots.length < 150,
          curveSmoothness: 0.2,
          color: AppColors.primary,
          barWidth: 2.2,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    // Add original scatter points
    if (originalSpots.isNotEmpty) {
      seriesNames.add('Data Node');
      lineBars.add(
        LineChartBarData(
          spots: originalSpots,
          barWidth: 0,
          dotData: FlDotData(
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 4.5,
                  color: AppColors.accent,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
          ),
        ),
      );
    }

    // Add predicted point marker
    if (predictedSpot != null) {
      seriesNames.add('Target Point');
      lineBars.add(
        LineChartBarData(
          spots: [predictedSpot],
          barWidth: 0,
          dotData: FlDotData(
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 6,
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
            key: Key('interpolation_chart_invalid_text'),
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
      key: const Key('interpolation_chart_repaint_boundary'),
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

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';

/// Helper utility adapting application design tokens and light/dark theme context
/// into fl_chart styling configurations (grid, axes, borders, and touch tooltips).
abstract final class ChartThemeAdapter {
  /// Formats a numeric axis value for concise, human-readable display.
  static String formatAxisNumber(double value) {
    if (value.abs() < 1e-12) return '0';
    if (value.abs() >= 10000 || (value.abs() < 0.001 && value != 0)) {
      return value.toStringAsExponential(2).replaceAll('e+', 'e');
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Trim trailing zeroes for clean representation
    return value
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  /// Formats a tooltip coordinate value with higher precision for inspection.
  static String formatTooltipNumber(double value) {
    if (value.abs() < 1e-12) return '0';
    if (value.abs() >= 100000 || (value.abs() < 0.0001 && value != 0)) {
      return value.toStringAsExponential(3).replaceAll('e+', 'e');
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(4)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  /// Builds standardized grid data with theme-aware dashed lines and zero-axis accent.
  static FlGridData buildGridData(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.35)
        : AppColors.lightBorder.withValues(alpha: 0.7);
    final zeroAxisColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.75)
        : AppColors.lightBorder.withValues(alpha: 0.95);

    return FlGridData(
      getDrawingHorizontalLine: (value) {
        final isZero = value.abs() < 1e-6;
        return FlLine(
          color: isZero ? zeroAxisColor : gridColor,
          strokeWidth: isZero ? 1.4 : 1.0,
          dashArray: isZero ? null : const [4, 4],
        );
      },
      getDrawingVerticalLine: (value) {
        final isZero = value.abs() < 1e-6;
        return FlLine(
          color: isZero ? zeroAxisColor : gridColor,
          strokeWidth: isZero ? 1.4 : 1.0,
          dashArray: isZero ? null : const [4, 4],
        );
      },
    );
  }

  /// Builds theme-aware axis title metadata.
  static FlTitlesData buildTitlesData(
    BuildContext context, {
    double? minX,
    double? maxX,
    double? minY,
    double? maxY,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final titleStyle = AppTypography.labelSmall.copyWith(
      color: textColor,
      fontSize: 10,
    );

    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          getTitlesWidget: (value, meta) {
            // Avoid drawing outside graph boundaries
            if (minX != null && value < minX) return const SizedBox.shrink();
            if (maxX != null && value > maxX) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                formatAxisNumber(value),
                style: titleStyle,
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          getTitlesWidget: (value, meta) {
            if (minY != null && value < minY) return const SizedBox.shrink();
            if (maxY != null && value > maxY) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                formatAxisNumber(value),
                textAlign: TextAlign.right,
                style: titleStyle,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds standard theme-aware border data.
  static FlBorderData buildBorderData(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return FlBorderData(
      show: true,
      border: Border(
        bottom: BorderSide(color: borderColor, width: 1.2),
        left: BorderSide(color: borderColor, width: 1.2),
      ),
    );
  }

  /// Builds theme-aware touch tooltip interaction data with overflow prevention and series labeling.
  static LineTouchData buildTouchData(
    BuildContext context, {
    String Function(int barIndex, FlSpot spot)? seriesNameResolver,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        maxContentWidth: 220,
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        tooltipRoundedRadius: AppSpacing.radiusSm,
        getTooltipColor: (_) => isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface.withValues(alpha: 0.95),
        tooltipBorder: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((barSpot) {
            final seriesLabel = seriesNameResolver != null
                ? seriesNameResolver(barSpot.barIndex, barSpot)
                : null;

            final coordText =
                '(${formatTooltipNumber(barSpot.x)}, ${formatTooltipNumber(barSpot.y)})';
            final text = seriesLabel != null
                ? '$seriesLabel\n$coordText'
                : coordText;

            return LineTooltipItem(
              text,
              AppTypography.labelSmall.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            );
          }).toList();
        },
      ),
    );
  }
}

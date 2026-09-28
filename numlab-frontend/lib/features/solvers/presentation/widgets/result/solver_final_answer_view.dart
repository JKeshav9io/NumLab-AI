import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';

/// Reusable generic view for displaying the `finalAnswer` payload across all 27 solvers.
class SolverFinalAnswerView extends StatelessWidget {
  const SolverFinalAnswerView({
    required this.finalAnswer,
    super.key,
  });

  final Map<String, dynamic> finalAnswer;

  static String formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'True' : 'False';
    if (value is num) {
      // Avoid excessive trailing zeros for integers represented as num
      if (value == value.roundToDouble() && !value.isInfinite && !value.isNaN) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    if (value is List) {
      if (value.isEmpty) return '[]';
      // 2D Matrix
      if (value.first is List) {
        return value
            .map((row) {
              if (row is List) {
                return '[ ${row.map(formatValue).join(', ')} ]';
              }
              return formatValue(row);
            })
            .join('\n');
      }
      // List of Point Maps
      if (value.first is Map) {
        return value
            .map((pt) {
              if (pt is Map) {
                final x = pt['x'];
                final y = pt['y'];
                if (x != null && y != null) {
                  return '(${formatValue(x)}, ${formatValue(y)})';
                }
              }
              return pt.toString();
            })
            .join(', ');
      }
      // 1D Vector
      return '[ ${value.map(formatValue).join(', ')} ]';
    }
    if (value is Map) {
      if (value.isEmpty) return '{}';
      return value.entries
          .map((e) => '${e.key}: ${formatValue(e.value)}')
          .join(', ');
    }
    return value.toString();
  }

  static String formatKeyLabel(String key) {
    // Convert camelCase or snake_case to Title Case (e.g. interpolatedValue -> Interpolated Value)
    final buffer = StringBuffer();
    for (var i = 0; i < key.length; i++) {
      final char = key[i];
      if (i > 0 &&
          char.toUpperCase() == char &&
          char.toLowerCase() != char &&
          key[i - 1] != '_') {
        buffer.write(' ');
      }
      if (char == '_') {
        buffer.write(' ');
      } else {
        buffer.write(char);
      }
    }
    final title = buffer.toString().trim();
    if (title.isEmpty) return key;
    return title[0].toUpperCase() + title.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (finalAnswer.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: const Key('solver_final_answer_section'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Final Results',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: finalAnswer.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
              ),
              itemBuilder: (context, index) {
                final entry = finalAnswer.entries.elementAt(index);
                final formattedKey = formatKeyLabel(entry.key);
                final formattedVal = formatValue(entry.value);
                final isMultiline = formattedVal.contains('\n');

                return Padding(
                  key: Key('final_answer_${entry.key}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: isMultiline
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedKey,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedVal,
                              style: AppTypography.codeMono.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                formattedKey,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 6,
                              child: Text(
                                formattedVal,
                                textAlign: TextAlign.end,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

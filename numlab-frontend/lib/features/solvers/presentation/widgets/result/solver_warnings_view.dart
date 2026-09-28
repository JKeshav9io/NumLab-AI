import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';

/// Reusable warning banner displaying non-fatal mathematical/solver warnings.
class SolverWarningsView extends StatelessWidget {
  const SolverWarningsView({
    required this.warnings,
    super.key,
  });

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const Key('solver_result_warnings'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Solver Warnings',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ...warnings.asMap().entries.map((entry) {
            final index = entry.key;
            final warning = entry.value;
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• $warning',
                key: Key('solver_warning_$index'),
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

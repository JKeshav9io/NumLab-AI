import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_explanation.dart';

/// Reusable explanation component displaying algorithmic or AI step-by-step reasoning.
class SolverExplanationView extends StatelessWidget {
  const SolverExplanationView({
    required this.explanation,
    super.key,
  });

  final SolverExplanation explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('solver_result_explanation'),
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppColors.info,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Step-by-Step Explanation',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (explanation.summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              explanation.summary,
              key: const Key('solver_explanation_summary'),
              style: AppTypography.bodyMedium,
            ),
          ],
          if (explanation.steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 12),
            const SizedBox(height: AppSpacing.xs),
            ...explanation.steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        key: Key('solver_explanation_step_$index'),
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

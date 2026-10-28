import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';

/// Minimal placeholder widget displayed when the user has zero historical calculation runs.
class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({super.key = const Key('history_empty_state')});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No history yet',
              key: Key('history_empty_title'),
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Calculation runs and mathematical solutions you perform will appear here.',
              key: Key('history_empty_subtitle'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_run.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_registry.dart';

/// Minimal functional list item rendering a single historical calculation run.
class HistoryListItem extends StatelessWidget {
  const HistoryListItem({
    required this.run,
    this.onTap,
    super.key,
  });

  final HistoryRun run;
  final VoidCallback? onTap;

  /// Resolves the human-readable method name.
  String get _methodName {
    final payloadMethod = run.outputPayload['method'] as String?;
    if (payloadMethod != null && payloadMethod.isNotEmpty) {
      return payloadMethod;
    }
    final config = SolverMethodRegistry.getById(run.method);
    if (config != null) {
      return config.name;
    }
    // Fallback: capitalize tokens in route key
    return run.method
        .split('/')
        .last
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  /// Resolves human-readable execution status.
  String get _statusText {
    final status = run.outputPayload['status']?.toString();
    if (status != null && status.isNotEmpty) {
      return status.replaceAll('_', ' ').toUpperCase();
    }
    final finalAnswer = run.outputPayload['finalAnswer'];
    if (finalAnswer is Map && finalAnswer['converged'] == true) {
      return 'CONVERGED';
    }
    return 'COMPLETED';
  }

  /// Formats creation date/time in YYYY-MM-DD HH:mm.
  String get _formattedDateTime {
    final local = run.createdAt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Color get _statusColor {
    final st = _statusText;
    if (st.contains('CONVERG') || st.contains('SUCCESS') || st == 'COMPLETED') {
      return AppColors.success;
    }
    if (st.contains('FAIL') || st.contains('ERROR') || st.contains('DIVERG')) {
      return AppColors.error;
    }
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('history_item_${run.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap:
            onTap ??
            () {
              final router = GoRouter.maybeOf(context);
              if (router != null) {
                context.go(AppRoutes.historyDetail(run.id));
              }
            },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.calculate_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _methodName,
                      key: Key('history_item_method_${run.id}'),
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          _statusText,
                          key: Key('history_item_status_${run.id}'),
                          style: AppTypography.codeMono.copyWith(
                            fontSize: 11,
                            color: _statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text('  •  ', style: AppTypography.labelSmall),
                        Expanded(
                          child: Text(
                            _formattedDateTime,
                            key: Key('history_item_date_${run.id}'),
                            style: AppTypography.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.darkTextSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/history/domain/usecases/get_history_runs_use_case.dart';
import 'package:numlab_frontend/injection_container.dart';

/// Minimal functional History summary section displayed on the authenticated Profile screen.
///
/// Exposes the total calculation count (derived directly from backend pagination metadata
/// `pagination.total`), handles loading/empty/error states gracefully without disrupting Profile,
/// and provides an action to navigate to the full calculation history screen (`/history`).
class ProfileHistoryCard extends StatefulWidget {
  const ProfileHistoryCard({
    this.getHistoryRunsUseCase,
    this.onViewHistory,
    super.key = const Key('profile_history_card'),
  });

  /// Optional use case instance override (e.g. for testing).
  final GetHistoryRunsUseCase? getHistoryRunsUseCase;

  /// Optional navigation override (e.g. for testing).
  final VoidCallback? onViewHistory;

  @override
  State<ProfileHistoryCard> createState() => _ProfileHistoryCardState();
}

class _ProfileHistoryCardState extends State<ProfileHistoryCard> {
  bool _isLoading = true;
  int? _totalRuns;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchSummary());
  }

  Future<void> _fetchSummary() async {
    final useCase =
        widget.getHistoryRunsUseCase ??
        (sl.isRegistered<GetHistoryRunsUseCase>()
            ? sl<GetHistoryRunsUseCase>()
            : null);

    if (useCase == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _totalRuns = 0;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await useCase(limit: 1);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (paginatedHistory) {
        setState(() {
          _isLoading = false;
          _totalRuns = paginatedHistory.pagination.total;
        });
      },
    );
  }

  void _onOpenHistory() {
    if (widget.onViewHistory != null) {
      widget.onViewHistory!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.go(AppRoutes.history);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history,
                  color: AppColors.primary,
                  size: 26,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Calculation History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (!_isLoading)
                  IconButton(
                    key: const Key('profile_history_refresh_button'),
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh History Count',
                    onPressed: _fetchSummary,
                  ),
              ],
            ),
            const Divider(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      key: Key('profile_history_loading_indicator'),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        key: const Key('profile_history_error_text'),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('profile_history_retry_button'),
                      onPressed: _fetchSummary,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Solves: ${_totalRuns ?? 0}',
                            key: const Key('profile_history_total_count'),
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            (_totalRuns == null || _totalRuns == 0)
                                ? 'No calculations performed yet'
                                : 'Persisted calculations across all categories',
                            key: const Key('profile_history_subtitle'),
                            style: AppTypography.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ElevatedButton.icon(
                        key: const Key('profile_history_view_all_button'),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View All'),
                        onPressed: _onOpenHistory,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

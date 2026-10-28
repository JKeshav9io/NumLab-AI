import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_run.dart';
import 'package:numlab_frontend/features/history/presentation/widgets/history_list_item.dart';

/// Scrollable history list view supporting pull-to-refresh and infinite scroll loading.
class HistoryList extends StatefulWidget {
  const HistoryList({
    required this.runs,
    required this.isLoadingMore,
    required this.hasMore,
    this.loadMoreError,
    this.onLoadMore,
    this.onRefresh,
    this.onRunTap,
    this.onRetryLoadMore,
    this.scrollController,
    super.key,
  });

  final List<HistoryRun> runs;
  final bool isLoadingMore;
  final bool hasMore;
  final String? loadMoreError;
  final VoidCallback? onLoadMore;
  final Future<void> Function()? onRefresh;
  final void Function(String runId)? onRunTap;
  final VoidCallback? onRetryLoadMore;
  final ScrollController? scrollController;

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  late final ScrollController _scrollController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore ||
        widget.isLoadingMore ||
        widget.loadMoreError != null) {
      return;
    }
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFooter = widget.isLoadingMore || widget.loadMoreError != null;

    return RefreshIndicator(
      key: const Key('history_refresh_indicator'),
      onRefresh: () async {
        await widget.onRefresh?.call();
      },
      child: ListView.builder(
        key: const Key('history_list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: widget.runs.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < widget.runs.length) {
            final run = widget.runs[index];
            return HistoryListItem(
              run: run,
              onTap: () => widget.onRunTap?.call(run.id),
            );
          }

          // Bottom loading more indicator or error retry banner
          if (widget.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    key: Key('history_load_more_indicator'),
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            );
          }

          if (widget.loadMoreError != null) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.loadMoreError!,
                        key: const Key('history_load_more_error_text'),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      key: const Key('history_load_more_retry_button'),
                      onPressed: widget.onRetryLoadMore,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

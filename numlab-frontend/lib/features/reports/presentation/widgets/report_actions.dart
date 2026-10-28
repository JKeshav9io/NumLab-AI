import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_run.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/report_delivery_bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/pages/report_preview_page.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_sharing.dart';
import 'package:numlab_frontend/injection_container.dart';

bool _isCurrentReport(
  BuildContext context, {
  required String runId,
  required String ownerId,
  required PdfReport report,
}) {
  if (!context.mounted) return false;
  final auth = context.read<AuthBloc>().state;
  final bloc = context.read<ReportBloc>();
  final current = bloc.state;
  return !bloc.isClosed &&
      auth is AuthAuthenticated &&
      auth.user.id == ownerId &&
      current is ReportSuccess &&
      current.runId == runId &&
      identical(current.report, report);
}

/// Only saved, owned history runs offer report generation. Live results have no ID.
class ReportActions extends StatelessWidget {
  const ReportActions({required this.run, super.key});

  final HistoryRun run;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc?>();
    if (auth == null) return const SizedBox.shrink();
    return BlocBuilder<AuthBloc, AuthState>(
      bloc: auth,
      builder: (context, state) {
        if (state is! AuthAuthenticated ||
            run.userId != state.user.id ||
            !_uuid.hasMatch(run.id) ||
            !sl.isRegistered<ReportBloc>() ||
            !sl.isRegistered<ReportDeliveryBloc>()) {
          return const SizedBox.shrink();
        }
        return MultiBlocProvider(
          key: ValueKey((run.id, state.user.id)),
          providers: [
            BlocProvider(create: (_) => sl<ReportBloc>()),
            BlocProvider(create: (_) => sl<ReportDeliveryBloc>()),
          ],
          child: _ReportActionsView(runId: run.id, ownerId: state.user.id),
        );
      },
    );
  }
}

class _ReportActionsView extends StatelessWidget {
  const _ReportActionsView({required this.runId, required this.ownerId});

  final String runId;
  final String ownerId;

  static String _generationError(Failure failure) => switch (failure) {
    AuthFailure() => 'Please sign in again to generate this report.',
    ValidationFailure() =>
      'This calculation cannot be exported. Open a saved run from History.',
    RateLimitFailure(:final retryAfterSeconds) =>
      retryAfterSeconds == null
          ? 'Too many report requests. Please wait before trying again.'
          : 'Too many report requests. The server requested a wait of $retryAfterSeconds seconds.',
    NetworkFailure(code: 'REQUEST_TIMEOUT') =>
      'Report generation timed out. Please try again.',
    NetworkFailure() =>
      'Could not connect. Check your connection and try again.',
    ServerFailure(statusCode: 404) =>
      'This saved calculation is no longer available.',
    _ => 'Could not generate the PDF. Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('report_actions'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: BlocBuilder<ReportBloc, ReportState>(
          builder: (context, state) {
            final loading = state is ReportLoading && state.runId == runId;
            final failure = state is ReportFailure && state.runId == runId
                ? state.failure
                : null;
            final report = state is ReportSuccess && state.runId == runId
                ? state.report
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'PDF report',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (report == null) ...[
                  if (failure != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _generationError(failure),
                        key: const Key('report_generation_error'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  ElevatedButton.icon(
                    key: const Key('report_generate_button'),
                    onPressed: loading
                        ? null
                        : () => context.read<ReportBloc>().add(
                            ReportRequested(runId: runId),
                          ),
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(
                      loading
                          ? 'Generating PDF…'
                          : failure == null
                          ? 'Generate PDF'
                          : 'Retry report',
                    ),
                  ),
                ] else ...[
                  const Text('PDF ready.', key: Key('report_ready')),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('report_preview_button'),
                    onPressed: () {
                      if (!_isCurrentReport(
                        context,
                        runId: runId,
                        ownerId: ownerId,
                        report: report,
                      )) {
                        return;
                      }
                      unawaited(
                        context.push<void>(
                          AppRoutes.reportPreview(runId),
                          extra: ReportPreviewSession(
                            runId: runId,
                            ownerId: ownerId,
                            bloc: context.read<ReportBloc>(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.preview_outlined),
                    label: const Text('Preview PDF'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BlocBuilder<ReportDeliveryBloc, ReportDeliveryState>(
                    builder: (context, delivery) {
                      final matching = identical(delivery.report, report);
                      final saving = delivery is ReportSaving;
                      final busy =
                          saving || delivery is ReportSharingInProgress;
                      final message = !matching
                          ? null
                          : switch (delivery) {
                              ReportSaving() => 'Saving PDF…',
                              ReportSaveFailure() => delivery.failure.message,
                              ReportDelivered(:final outcome) =>
                                switch (outcome) {
                                  ReportDeliveryOutcome.saved => 'PDF saved.',
                                  ReportDeliveryOutcome.cancelled =>
                                    'Save cancelled. The PDF is still ready.',
                                  ReportDeliveryOutcome.downloadRequested =>
                                    'Download requested. Check your browser downloads.',
                                },
                              _ => null,
                            };
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (context
                              .read<ReportDeliveryBloc>()
                              .supportsSharing) ...[
                            _ReportShareAction(
                              runId: runId,
                              ownerId: ownerId,
                              report: report,
                              state: delivery,
                              busy: busy,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          ElevatedButton.icon(
                            key: const Key('report_save_button'),
                            onPressed: busy
                                ? null
                                : () {
                                    if (!_isCurrentReport(
                                      context,
                                      runId: runId,
                                      ownerId: ownerId,
                                      report: report,
                                    )) {
                                      return;
                                    }
                                    context.read<ReportDeliveryBloc>().add(
                                      ReportSaveRequested(report),
                                    );
                                  },
                            icon: const Icon(Icons.save_alt),
                            label: Text(saving ? 'Saving PDF…' : 'Save PDF'),
                          ),
                          if (message != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                message,
                                key: const Key('report_delivery_message'),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportShareAction extends StatelessWidget {
  const _ReportShareAction({
    required this.runId,
    required this.ownerId,
    required this.report,
    required this.state,
    required this.busy,
  });

  final String runId;
  final String ownerId;
  final PdfReport report;
  final ReportDeliveryState state;
  final bool busy;

  void _share(BuildContext context) {
    if (!_isCurrentReport(
      context,
      runId: runId,
      ownerId: ownerId,
      report: report,
    )) {
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    context.read<ReportDeliveryBloc>().add(
      ReportShareRequested(
        report,
        origin: box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matching = identical(state.report, report);
    final sharing = matching && state is ReportSharingInProgress;
    final message = !matching
        ? null
        : switch (state) {
            ReportShareFailure() =>
              (state as ReportShareFailure).failure.message,
            ReportShareFinished(:final outcome) => switch (outcome) {
              ReportShareOutcome.targetSelected =>
                'Sharing target selected. Completion is not confirmed.',
              ReportShareOutcome.cancelled =>
                'Share cancelled. The PDF is still ready.',
              ReportShareOutcome.unconfirmed =>
                'Sharing returned no confirmed result. Check the sharing app.',
              ReportShareOutcome.unsupported =>
                'PDF sharing is unavailable on this platform or browser. Use Save PDF.',
              ReportShareOutcome.busy =>
                'Another share is still open. Finish it before trying again.',
            },
            _ => null,
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (buttonContext) => OutlinedButton.icon(
            key: const Key('report_share_button'),
            onPressed: busy || report.bytes.isEmpty
                ? null
                : () => _share(buttonContext),
            icon: sharing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            label: Text(sharing ? 'Opening sharing…' : 'Share PDF'),
          ),
        ),
        if (message != null || report.bytes.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              message ??
                  'PDF data is unavailable. Return to Calculation Detail.',
              key: const Key('report_share_message'),
            ),
          ),
        ],
      ],
    );
  }
}

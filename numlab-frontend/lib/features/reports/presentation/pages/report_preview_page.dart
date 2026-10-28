import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_preview_renderer.dart';
import 'package:numlab_frontend/injection_container.dart';

/// In-memory navigation context, borrowing the detail action's BLoC lifetime.
/// Contains no second PDF model, serialized bytes, or persistence mechanism.
class ReportPreviewSession {
  const ReportPreviewSession({
    required this.runId,
    required this.ownerId,
    required this.bloc,
  });

  final String runId;
  final String ownerId;
  final ReportBloc bloc;

  bool get hasPersistedRunId => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(runId);
}

class ReportPreviewPage extends StatelessWidget {
  const ReportPreviewPage({required this.runId, this.session, super.key});

  final String runId;
  final ReportPreviewSession? session;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.historyDetail(runId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('report_preview_screen'),
    appBar: AppBar(
      title: const Text('PDF preview'),
      leading: IconButton(
        key: const Key('report_preview_back'),
        tooltip: 'Back to calculation',
        onPressed: () => _back(context),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(child: _body(context)),
  );

  Widget _body(BuildContext context) {
    final source = session;
    final auth = context.read<AuthBloc?>();
    if (source == null ||
        auth == null ||
        !source.hasPersistedRunId ||
        source.runId != runId ||
        source.bloc.isClosed) {
      return _unavailable;
    }
    return BlocBuilder<AuthBloc, AuthState>(
      bloc: auth,
      builder: (context, authState) {
        if (authState is! AuthAuthenticated ||
            authState.user.id != source.ownerId) {
          return _unavailable;
        }
        return BlocBuilder<ReportBloc, ReportState>(
          bloc: source.bloc,
          builder: (context, state) {
            if (source.bloc.isClosed ||
                state is! ReportSuccess ||
                state.runId != runId) {
              return _unavailable;
            }
            final report = state.report;
            if (report.bytes.isEmpty) {
              return const ReportPreviewMessage(
                message:
                    'This PDF contains no data. Return to the calculation.',
              );
            }
            final filename = report.filename;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (filename != null && filename.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      filename,
                      key: const Key('report_preview_filename'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                Expanded(
                  child: sl<ReportPreviewRenderer>().build(
                    context,
                    runId: runId,
                    report: report,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static const _unavailable = ReportPreviewMessage(
    message:
        'No PDF is available for this calculation. Return to Calculation Detail and generate a report.',
  );
}

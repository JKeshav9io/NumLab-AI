import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:pdfrx/pdfrx.dart';

/// Isolates the platform viewer so workflow tests need no native PDF engine.
// ignore: one_member_abstracts
abstract interface class ReportPreviewRenderer {
  Widget build(
    BuildContext context, {
    required String runId,
    required PdfReport report,
  });
}

class PdfrxReportPreviewRenderer implements ReportPreviewRenderer {
  const PdfrxReportPreviewRenderer({this.platform, this.isWeb = kIsWeb});

  final TargetPlatform? platform;
  final bool isWeb;

  @override
  Widget build(
    BuildContext context, {
    required String runId,
    required PdfReport report,
  }) {
    if (!isWeb &&
        (platform ?? defaultTargetPlatform) == TargetPlatform.fuchsia) {
      return const ReportPreviewMessage(
        message:
            'PDF preview is not supported on this platform. Return to the calculation to save the PDF.',
      );
    }
    if (report.bytes.isEmpty) {
      return const ReportPreviewMessage(message: 'This PDF contains no data.');
    }
    return PdfViewer.data(
      report.bytes,
      key: ObjectKey(report),
      // An opaque local viewer identity, not filename metadata or a file path.
      sourceName: 'report-${identityHashCode(report)}',
      params: PdfViewerParams(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        // Keep the library's bounded, on-demand page image cache.
        maxImageBytesCachedOnMemory: 32 * 1024 * 1024,
        loadingBannerBuilder: (_, _, _) => const ReportPreviewLoading(),
        errorBannerBuilder: (_, _, _, _) => const ReportPreviewMessage(
          message:
              'This PDF could not be displayed. Return to the calculation to save it or try preview again.',
        ),
        // Links are disabled by default; no external URL/file actions enabled.
      ),
    );
  }
}

class ReportPreviewLoading extends StatelessWidget {
  const ReportPreviewLoading({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('Opening PDF…'),
        ],
      ),
    ),
  );
}

class ReportPreviewMessage extends StatelessWidget {
  const ReportPreviewMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Semantics(
        liveRegion: true,
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}

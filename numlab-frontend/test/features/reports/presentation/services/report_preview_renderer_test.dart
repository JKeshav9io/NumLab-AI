import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/theme/app_theme.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_preview_renderer.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  final report = PdfReport(bytes: const [1, 2, 3], filename: 'server.pdf');

  Future<void> inspectViewer(
    WidgetTester tester,
    Widget Function(BuildContext, PdfViewer) inspect,
  ) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final viewer =
                const PdfrxReportPreviewRenderer().build(
                      context,
                      runId: 'calculation',
                      report: report,
                    )
                    as PdfViewer;
            return inspect(context, viewer);
          },
        ),
      ),
    ),
  );

  testWidgets('passes the original byte buffer to the public data API', (
    tester,
  ) async {
    await inspectViewer(tester, (_, viewer) {
      final source = viewer.documentRef as PdfDocumentRefData;
      expect(source.data, same(report.bytes));
      expect(source.key.toString(), isNot(contains('server.pdf')));
      expect(viewer.key, ObjectKey(report));
      expect(viewer.params.panEnabled, isTrue);
      expect(viewer.params.scaleEnabled, isTrue);
      expect(viewer.params.enableKeyboardNavigation, isTrue);
      expect(viewer.params.linkHandlerParams, isNull);
      expect(viewer.params.maxImageBytesCachedOnMemory, 32 * 1024 * 1024);
      return const SizedBox.shrink();
    });
  });

  testWidgets('opening feedback uses no invented download percentage', (
    tester,
  ) async {
    await inspectViewer(tester, (context, viewer) {
      return viewer.params.loadingBannerBuilder!(context, 0, null);
    });
    expect(find.text('Opening PDF…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('rendering error is safe and offers return/save guidance', (
    tester,
  ) async {
    await inspectViewer(tester, (context, viewer) {
      return viewer.params.errorBannerBuilder!(
        context,
        StateError('private bytes token and filesystem path'),
        StackTrace.current,
        viewer.documentRef,
      );
    });
    expect(
      find.textContaining('This PDF could not be displayed'),
      findsOneWidget,
    );
    expect(find.textContaining('private'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final platform in TargetPlatform.values) {
    testWidgets('handles $platform explicitly without loading a PDF engine', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final widget = PdfrxReportPreviewRenderer(
                platform: platform,
                isWeb: false,
              ).build(context, runId: 'calculation', report: report);
              expect(
                widget,
                platform == TargetPlatform.fuchsia
                    ? isA<ReportPreviewMessage>()
                    : isA<PdfViewer>(),
              );
              return widget is PdfViewer ? const SizedBox.shrink() : widget;
            },
          ),
        ),
      );
      if (platform == TargetPlatform.fuchsia) {
        expect(find.textContaining('not supported'), findsOneWidget);
      }
    });
  }

  testWidgets('web selects the WASM-capable viewer independently of host', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(
              const PdfrxReportPreviewRenderer(
                platform: TargetPlatform.fuchsia,
                isWeb: true,
              ).build(context, runId: 'calculation', report: report),
              isA<PdfViewer>(),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets(
    'empty bytes display a clear message without opening the engine',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => const PdfrxReportPreviewRenderer().build(
              context,
              runId: 'calculation',
              report: PdfReport(bytes: const []),
            ),
          ),
        ),
      );
      expect(find.text('This PDF contains no data.'), findsOneWidget);
      expect(find.byType(PdfViewer), findsNothing);
    },
  );
}

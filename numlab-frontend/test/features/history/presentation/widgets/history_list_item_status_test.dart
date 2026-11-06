import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/features/history/data/models/history_run_model.dart';
import 'package:numlab_frontend/features/history/presentation/widgets/history_list_item.dart';

HistoryRunModel _run({
  Map<String, dynamic> summary = const {},
  Map<String, dynamic> output = const {},
}) => HistoryRunModel.fromJson({
  'id': 'status-run',
  'method': 'root/bisection',
  'createdAt': '2026-11-06T00:00:00.000Z',
  'summary_payload': summary,
  'outputPayload': output,
});

Future<void> _pump(
  WidgetTester tester,
  HistoryRunModel run, {
  bool dark = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: dark ? ThemeData.dark() : ThemeData.light(),
    home: Scaffold(
      body: HistoryListItem(run: run, onTap: () {}),
    ),
  ),
);

Text _statusLabel(WidgetTester tester) => tester.widget<Text>(
  find
      .descendant(
        of: find.byKey(const Key('history_item_status_status-run')),
        matching: find.byType(Text),
        matchRoot: true,
      )
      .first,
);

void main() {
  testWidgets('an empty summary must not claim successful completion', (
    tester,
  ) async {
    final run = _run();
    await _pump(tester, run);

    expect(tester.takeException(), isNull);
    expect(run.summaryPayload, isEmpty);
    expect(find.text('COMPLETED'), findsNothing);
    final context = tester.element(find.byType(HistoryListItem));
    expect(
      _statusLabel(tester).style?.color,
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
  });

  testWidgets(
    'a compact failed summary retains its supplied numerical status',
    (
      tester,
    ) async {
      await _pump(tester, _run(summary: {'status': 'failed'}));

      expect(tester.takeException(), isNull);
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('COMPLETED'), findsNothing);
      expect(_statusLabel(tester).style?.color, AppColors.error);
    },
  );

  for (final dark in [false, true]) {
    for (final status in <String?>[
      null,
      '',
      '   ',
      'unknown',
      'unsuccessful',
      'completed_with_errors',
      'converged',
    ]) {
      testWidgets('status "$status" stays neutral in dark=$dark', (
        tester,
      ) async {
        await _pump(tester, _run(summary: {'status': status}), dark: dark);

        final context = tester.element(find.byType(HistoryListItem));
        expect(
          _statusLabel(tester).style?.color,
          Theme.of(context).colorScheme.onSurfaceVariant,
        );
        expect(find.text('COMPLETED'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an explicit completed status is green in dark=$dark', (
      tester,
    ) async {
      await _pump(tester, _run(summary: {'status': ' completed '}), dark: dark);

      expect(find.text('COMPLETED'), findsOneWidget);
      expect(_statusLabel(tester).style?.color, AppColors.success);
      expect(tester.takeException(), isNull);
    });

    testWidgets('legacy failed output retains failure styling in dark=$dark', (
      tester,
    ) async {
      await _pump(tester, _run(output: {'status': 'failed'}), dark: dark);

      expect(find.text('FAILED'), findsOneWidget);
      expect(_statusLabel(tester).style?.color, AppColors.error);
    });
  }
}

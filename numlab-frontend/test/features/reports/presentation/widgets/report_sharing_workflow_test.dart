import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_theme.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_run.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/report_delivery_bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_preview_renderer.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_sharing.dart';
import 'package:numlab_frontend/injection_container.dart';

import '../bloc/report_share_bloc_test.dart';
import '../pages/report_preview_page_test.dart';
import 'report_actions_test.dart';

void main() {
  const id = '550e8400-e29b-41d4-a716-446655440000';
  const nextId = '550e8400-e29b-41d4-a716-446655440001';
  final user = User(
    id: 'student',
    email: 'student@example.com',
    emailVerified: true,
    createdAt: DateTime(2026),
  );
  final report = PdfReport(
    bytes: const [37, 255, 0, 80],
    filename: 'server.pdf',
  );
  late TestAuth auth;
  late TestGenerate generate;
  late TestDelivery delivery;
  late TestReportSharing sharing;
  late AppRouter router;
  late HistoryRun selected;
  late List<PreviewRouteHistory> histories;
  late List<ReportBloc> reportBlocs;
  HistoryRun run({String runId = id, String? owner = 'student'}) => HistoryRun(
    id: runId,
    userId: owner,
    method: 'root/bisection',
    createdAt: DateTime(2026),
    outputPayload: const {
      'method': 'Bisection Method',
      'status': 'converged',
      'finalAnswer': {'root': 2.0},
    },
  );
  void widgetCase(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await sl.reset();
      auth = TestAuth(AuthAuthenticated(user: user));
      selected = run();
      histories = [];
      reportBlocs = [];
      generate = TestGenerate()..handler = (_) async => Right(report);
      delivery = TestDelivery()
        ..handler = () async => ReportDeliveryOutcome.saved;
      sharing = TestReportSharing()
        ..handler = () async => ReportShareOutcome.targetSelected;
      sl
        ..registerFactory<ReportBloc>(() {
          final bloc = ReportBloc(generateReportUseCase: generate);
          reportBlocs.add(bloc);
          return bloc;
        })
        ..registerFactory<ReportDeliveryBloc>(
          () => ReportDeliveryBloc(delivery: delivery, sharing: sharing),
        )
        ..registerFactory<HistoryBloc>(() {
          final bloc = PreviewRouteHistory(selected);
          histories.add(bloc);
          return bloc;
        })
        ..registerSingleton<ReportPreviewRenderer>(TestPreviewRenderer());
      router = AppRouter(
        authBloc: auth,
        initialLocation: AppRoutes.historyDetail(id),
      );
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        router.dispose();
        await auth.close();
        for (final bloc in histories) {
          await bloc.close();
        }
        for (final bloc in reportBlocs) {
          if (!bloc.isClosed) await tester.runAsync(bloc.close);
        }
        await sl.reset();
      }
    });
  }

  Future<void> launch(WidgetTester tester, {bool dark = false}) async {
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp.router(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          routerConfig: router.router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump();
  }

  Future<void> generatePdf(WidgetTester tester) =>
      tap(tester, 'report_generate_button');
  Finder shareButton() => find.byKey(const Key('report_share_button'));

  widgetCase(
    'eligible history shares the exact ready PDF without another API request',
    (tester) async {
      await launch(tester);
      expect(shareButton(), findsNothing);
      await generatePdf(tester);
      expect(shareButton(), findsOneWidget);
      await tap(tester, 'report_share_button');
      expect(sharing.reports.single, same(report));
      expect(sharing.reports.single.bytes, same(report.bytes));
      expect(sharing.origins.single.isEmpty, isFalse);
      expect(sharing.origins.single.isFinite, isTrue);
      expect(generate.ids, [id]);
      expect(delivery.reports, isEmpty);
      expect(
        find.text('Sharing target selected. Completion is not confirmed.'),
        findsOneWidget,
      );
      expect(find.text('PDF shared.'), findsNothing);
    },
  );

  for (final value in ['guest', 'invalid', 'no owner', 'other owner']) {
    widgetCase('$value has no share workflow', (tester) async {
      if (value == 'guest') auth.current = const AuthUnauthenticated();
      selected = run(
        runId: value == 'invalid' ? 'unsaved' : id,
        owner: value == 'no owner'
            ? null
            : value == 'other owner'
            ? 'other'
            : 'student',
      );
      await launch(tester);
      expect(shareButton(), findsNothing);
      expect(sharing.reports, isEmpty);
      expect(generate.ids, isEmpty);
    });
  }
  widgetCase('generation loading and failure never offer sharing', (
    tester,
  ) async {
    final pending = Completer<Either<Failure, PdfReport>>();
    generate.handler = (_) => pending.future;
    await launch(tester);
    await generatePdf(tester);
    expect(find.text('Generating PDF…'), findsOneWidget);
    expect(shareButton(), findsNothing);
    pending.complete(const Left(ServerFailure(message: 'private response')));
    await tester.pumpAndSettle();
    expect(shareButton(), findsNothing);
    expect(
      find.text('Could not generate the PDF. Please try again.'),
      findsOneWidget,
    );
    expect(sharing.reports, isEmpty);
  });
  widgetCase(
    'rapid taps open one share operation and disable save until it finishes',
    (tester) async {
      final pending = Completer<ReportShareOutcome>();
      sharing.handler = () => pending.future;
      await launch(tester);
      await generatePdf(tester);
      await tester.ensureVisible(shareButton());
      final original = tester.widget<OutlinedButton>(shareButton()).onPressed!;
      original();
      original();
      original();
      await tester.pump();
      await tester.pump();
      expect(sharing.reports, hasLength(1));
      expect(find.text('Opening sharing…'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(shareButton()).onPressed, isNull);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('report_save_button')))
            .onPressed,
        isNull,
      );
      pending.complete(ReportShareOutcome.cancelled);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('report_save_button')))
            .onPressed,
        isNotNull,
      );
    },
  );
  for (final outcome in ReportShareOutcome.values) {
    widgetCase('displays the honest outcome: $outcome', (tester) async {
      sharing.handler = () async => outcome;
      await launch(tester);
      await generatePdf(tester);
      await tap(tester, 'report_share_button');
      final text = tester
          .widget<Text>(find.byKey(const Key('report_share_message')))
          .data!;
      expect(text, switch (outcome) {
        ReportShareOutcome.cancelled => contains('Share cancelled'),
        ReportShareOutcome.targetSelected => contains(
          'Completion is not confirmed',
        ),
        ReportShareOutcome.unconfirmed => contains('no confirmed result'),
        ReportShareOutcome.unsupported => contains(
          'unavailable on this platform or browser',
        ),
        ReportShareOutcome.busy => contains('Another share is still open'),
      });
      expect(find.text('PDF shared.'), findsNothing);
      expect(find.byKey(const Key('report_generation_error')), findsNothing);
      expect(generate.ids, [id]);
    });
  }
  widgetCase(
    'safe share failure can retry without generation or a false save result',
    (tester) async {
      sharing.handler = () async =>
          throw Exception('private token/path/target');
      await launch(tester);
      await generatePdf(tester);
      await tap(tester, 'report_share_button');
      expect(
        find.text('Could not open sharing. Try again, or use Save PDF.'),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);
      expect(find.text('PDF saved.'), findsNothing);
      sharing.handler = () async => ReportShareOutcome.unconfirmed;
      await tap(tester, 'report_share_button');
      expect(sharing.reports, [report, report]);
      expect(generate.ids, [id]);
    },
  );
  widgetCase('preview/back, share and save reuse the same generated report', (
    tester,
  ) async {
    await launch(tester);
    await generatePdf(tester);
    await tap(tester, 'report_preview_button');
    await tester.pumpAndSettle();
    expect(find.text('Rendered PDF'), findsOneWidget);
    await tap(tester, 'report_preview_back');
    await tester.pumpAndSettle();
    await tap(tester, 'report_share_button');
    await tap(tester, 'report_save_button');
    expect(sharing.reports.single, same(report));
    expect(delivery.reports.single, same(report));
    expect(generate.ids, [id]);
    expect(find.text('PDF saved.'), findsOneWidget);
  });
  for (final changed in ['account', 'result']) {
    widgetCase(
      'queued share callback rejects a changed $changed before rebuild',
      (tester) async {
        await launch(tester);
        await generatePdf(tester);
        final oldTap = tester.widget<OutlinedButton>(shareButton()).onPressed!;
        if (changed == 'account') {
          auth.change(
            AuthAuthenticated(
              user: User(
                id: 'other',
                email: 'other@example.com',
                emailVerified: true,
                createdAt: DateTime(2026),
              ),
            ),
          );
        } else {
          reportBlocs.single.add(const ReportRequested(runId: nextId));
          await tester.pump();
        }
        oldTap();
        await tester.pumpAndSettle();
        expect(sharing.reports, isEmpty);
      },
    );
  }
  widgetCase('an empty generated value cannot start sharing', (tester) async {
    generate.handler = (_) async => Right(PdfReport(bytes: const []));
    await launch(tester);
    await generatePdf(tester);
    expect(tester.widget<OutlinedButton>(shareButton()).onPressed, isNull);
    expect(find.textContaining('PDF data is unavailable'), findsOneWidget);
    expect(sharing.reports, isEmpty);
  });
  widgetCase(
    'pending share completion cannot appear for a different calculation',
    (tester) async {
      final pending = Completer<ReportShareOutcome>();
      sharing.handler = () => pending.future;
      await launch(tester);
      await generatePdf(tester);
      await tap(tester, 'report_share_button');
      selected = run(runId: nextId);
      router.router.go(AppRoutes.history);
      await tester.pumpAndSettle();
      router.router.go(AppRoutes.historyDetail(nextId));
      await tester.pumpAndSettle();
      expect(shareButton(), findsNothing);
      await generatePdf(tester);
      pending.complete(ReportShareOutcome.targetSelected);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_share_message')), findsNothing);
      expect(generate.ids, [id, nextId]);
      expect(sharing.reports, hasLength(1));
    },
  );
  widgetCase(
    'logout during sharing removes the action and ignores late status',
    (tester) async {
      final pending = Completer<ReportShareOutcome>();
      sharing.handler = () => pending.future;
      await launch(tester);
      await generatePdf(tester);
      await tap(tester, 'report_share_button');
      auth.change(const AuthUnauthenticated());
      await tester.pumpAndSettle();
      pending.complete(ReportShareOutcome.targetSelected);
      await tester.pumpAndSettle();
      expect(shareButton(), findsNothing);
      expect(find.byKey(const Key('report_share_message')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final action in ['save', 'preview']) {
    for (final changed in ['account', 'run', 'report', 'disposed']) {
      widgetCase('queued report action $action rejects $changed changes', (
        tester,
      ) async {
        await launch(tester);
        await generatePdf(tester);
        final button = find.byKey(Key('report_${action}_button'));
        final oldTap = action == 'save'
            ? tester.widget<ElevatedButton>(button).onPressed!
            : tester.widget<OutlinedButton>(button).onPressed!;
        if (changed == 'account') {
          auth.change(
            AuthAuthenticated(
              user: User(
                id: 'other-account',
                email: 'other@example.com',
                emailVerified: true,
                createdAt: DateTime(2026),
              ),
            ),
          );
        } else if (changed == 'disposed') {
          router.router.go(AppRoutes.history);
          await tester.pumpAndSettle();
        } else {
          generate.handler = (_) async => Right(
            PdfReport(
              bytes: report.bytes,
              filename: 'newer-report.pdf',
            ),
          );
          reportBlocs.single.add(
            ReportRequested(
              runId: changed == 'run' ? nextId : id,
            ),
          );
          await tester.pump();
          await tester.pump();
        }
        oldTap();
        await tester.pumpAndSettle();
        expect(delivery.reports, isEmpty);
        expect(sharing.reports, isEmpty);
        expect(find.byKey(const Key('report_preview_screen')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final dark in [false, true]) {
    widgetCase('320px report actions and sharing guidance fit: dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      sharing.handler = () async => ReportShareOutcome.unsupported;
      await launch(tester, dark: dark);
      await generatePdf(tester);
      await tap(tester, 'report_share_button');
      expect(find.textContaining('Use Save PDF.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

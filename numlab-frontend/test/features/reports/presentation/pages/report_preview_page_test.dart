import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
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
import 'package:numlab_frontend/features/reports/presentation/pages/report_preview_page.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_preview_renderer.dart';
import 'package:numlab_frontend/injection_container.dart';

import '../widgets/report_actions_test.dart';

class TestPreviewRenderer implements ReportPreviewRenderer {
  final reports = <PdfReport>[];
  final runIds = <String>[];
  Widget child = const Text('Rendered PDF');

  @override
  Widget build(
    BuildContext context, {
    required String runId,
    required PdfReport report,
  }) {
    reports.add(report);
    runIds.add(runId);
    return child;
  }
}

/// The real router mounts the history list below detail; each route owns a BLoC.
class PreviewRouteHistory extends TestHistory {
  PreviewRouteHistory(super.run);

  final events = <HistoryEvent>[];

  @override
  void add(HistoryEvent event) {
    events.add(event);
    if (event is HistoryRunRequested) {
      current = const HistoryError(
        failure: ServerFailure(message: 'Not found', statusCode: 404),
      );
    } else {
      expect(event, isA<HistoryLoadRequested>());
    }
  }
}

void main() {
  const runId = '550e8400-e29b-41d4-a716-446655440000';
  const otherRunId = '550e8400-e29b-41d4-a716-446655440001';
  final user = User(
    id: 'student',
    email: 'test@example.com',
    emailVerified: true,
    createdAt: DateTime(2026),
  );
  final report = PdfReport(bytes: const [1, 2, 3], filename: 'server.pdf');
  late TestAuth auth;
  late TestGenerate generate;
  late TestDelivery delivery;
  late TestPreviewRenderer renderer;
  late TestHistory history;
  late AppRouter router;
  late List<ReportBloc> blocs;
  late List<PreviewRouteHistory> routeHistories;

  HistoryRun savedRun({String id = runId, String? owner = 'student'}) =>
      HistoryRun(
        id: id,
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
      generate = TestGenerate()..handler = (_) async => Right(report);
      delivery = TestDelivery()
        ..handler = () async => ReportDeliveryOutcome.saved;
      renderer = TestPreviewRenderer();
      history = TestHistory(savedRun());
      blocs = [];
      routeHistories = [];
      sl
        ..registerFactory<ReportBloc>(() {
          final bloc = ReportBloc(generateReportUseCase: generate);
          blocs.add(bloc);
          return bloc;
        })
        ..registerFactory<ReportDeliveryBloc>(
          () => ReportDeliveryBloc(delivery: delivery),
        )
        ..registerFactory<HistoryBloc>(() {
          final bloc = PreviewRouteHistory(
            (history.current as HistoryDetailLoaded).run,
          );
          routeHistories.add(bloc);
          return bloc;
        })
        ..registerSingleton<ReportPreviewRenderer>(renderer);
      router = AppRouter(
        authBloc: auth,
        initialLocation: AppRoutes.historyDetail(runId),
      );
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        router.dispose();
        for (final bloc in blocs) {
          if (!bloc.isClosed) {
            await tester.runAsync(bloc.close);
          }
        }
        await auth.close();
        await history.close();
        for (final bloc in routeHistories) {
          await bloc.close();
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
    final button = find.byKey(Key(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    await tap(tester, 'report_generate_button');
    await tap(tester, 'report_preview_button');
    await tester.pumpAndSettle();
  }

  Future<void> goPreview(
    WidgetTester tester, {
    String pathId = runId,
    String sourceId = runId,
    String owner = 'student',
    ReportBloc? bloc,
  }) async {
    unawaited(
      router.router.push<void>(
        AppRoutes.reportPreview(pathId),
        extra: ReportPreviewSession(
          runId: sourceId,
          ownerId: owner,
          bloc: bloc ?? blocs.single,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  widgetCase(
    'preview is available only after success, with exact bytes and run',
    (
      tester,
    ) async {
      await launch(tester);
      expect(find.byKey(const Key('report_preview_button')), findsNothing);
      await tap(tester, 'report_generate_button');
      expect(find.byKey(const Key('report_preview_button')), findsOneWidget);
      expect(find.byKey(const Key('report_save_button')), findsOneWidget);
      await tap(tester, 'report_preview_button');
      await tester.pumpAndSettle();
      expect(
        GoRouterState.of(
          tester.element(find.byType(ReportPreviewPage)),
        ).uri.path,
        AppRoutes.reportPreview(runId),
      );
      expect(find.text('PDF preview'), findsOneWidget);
      expect(find.text('server.pdf'), findsOneWidget);
      expect(find.text('Rendered PDF'), findsOneWidget);
      expect(renderer.runIds, everyElement(runId));
      expect(renderer.reports, everyElement(same(report)));
      expect(renderer.reports.single.bytes, same(report.bytes));
      expect(generate.ids, [runId]);
      expect(delivery.reports, isEmpty);
    },
  );

  widgetCase(
    'back preserves Save PDF; reopening and rebuild never regenerate',
    (
      tester,
    ) async {
      await launch(tester);
      await open(tester);
      await launch(tester, dark: true);
      expect(find.text('Rendered PDF'), findsOneWidget);
      await tap(tester, 'report_preview_back');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_detail_screen')), findsOneWidget);
      expect(find.text('PDF ready.'), findsOneWidget);
      expect(blocs.single.isClosed, isFalse);
      await tap(tester, 'report_save_button');
      expect(delivery.reports.single, same(report));
      expect(find.text('PDF saved.'), findsOneWidget);
      await tap(tester, 'report_preview_button');
      await tester.pumpAndSettle();
      expect(find.text('Rendered PDF'), findsOneWidget);
      expect(generate.ids, [runId]);
    },
  );

  widgetCase('system back returns to the existing calculation and save state', (
    tester,
  ) async {
    await launch(tester);
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report_preview_screen')), findsNothing);
    expect(find.byKey(const Key('report_save_button')), findsOneWidget);
    expect(generate.ids, [runId]);
  });

  widgetCase('loading cannot preview and repeated taps generate once', (
    tester,
  ) async {
    final pending = Completer<Either<Failure, PdfReport>>();
    generate.handler = (_) => pending.future;
    await launch(tester);
    await tap(tester, 'report_generate_button');
    expect(find.text('Generating PDF…'), findsOneWidget);
    expect(find.byKey(const Key('report_preview_button')), findsNothing);
    await tester.tap(find.byKey(const Key('report_generate_button')));
    await tester.pump();
    expect(generate.ids, [runId]);
    pending.complete(Right(report));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report_preview_button')), findsOneWidget);
  });

  widgetCase('generation failure has a safe manual retry before preview', (
    tester,
  ) async {
    generate.handler = (_) async => const Left(
      ServerFailure(message: 'private payload and token', statusCode: 500),
    );
    await launch(tester);
    await tap(tester, 'report_generate_button');
    expect(
      find.text('Could not generate the PDF. Please try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('report_preview_button')), findsNothing);
    generate.handler = (_) async => Right(report);
    await tap(tester, 'report_generate_button');
    await tap(tester, 'report_preview_button');
    await tester.pumpAndSettle();
    expect(find.text('Rendered PDF'), findsOneWidget);
    expect(generate.ids, [runId, runId]);
  });

  for (final mismatch in ['path', 'source', 'owner']) {
    widgetCase('rejects a preview session with mismatched $mismatch', (
      tester,
    ) async {
      await launch(tester);
      await tap(tester, 'report_generate_button');
      await goPreview(
        tester,
        pathId: mismatch == 'path' ? otherRunId : runId,
        sourceId: mismatch == 'source' ? otherRunId : runId,
        owner: mismatch == 'owner' ? 'someone-else' : 'student',
      );
      expect(find.textContaining('No PDF is available'), findsOneWidget);
      expect(renderer.reports, isEmpty);
      expect(generate.ids, [runId]);
    });
  }

  widgetCase(
    'a newer run loading or completing invalidates the visible preview',
    (
      tester,
    ) async {
      await launch(tester);
      await open(tester);
      final next = Completer<Either<Failure, PdfReport>>();
      generate.handler = (_) => next.future;
      blocs.single.add(const ReportRequested(runId: otherRunId));
      await tester.pumpAndSettle();
      expect(find.text('Rendered PDF'), findsNothing);
      expect(find.textContaining('No PDF is available'), findsOneWidget);
      next.complete(Right(report));
      await tester.pumpAndSettle();
      expect(find.text('Rendered PDF'), findsNothing);
      expect(renderer.runIds, everyElement(runId));
    },
  );

  for (final missing in ['initial', 'loading', 'failure', 'closed']) {
    widgetCase('does not render a $missing report source', (tester) async {
      await launch(tester);
      final source = blocs.single;
      final pending = Completer<Either<Failure, PdfReport>>();
      if (missing == 'loading') {
        generate.handler = (_) => pending.future;
        source.add(const ReportRequested(runId: runId));
        await tester.pump();
      } else if (missing == 'failure') {
        generate.handler = (_) async =>
            const Left(NetworkFailure(message: 'offline'));
        source.add(const ReportRequested(runId: runId));
        await tester.pump();
        await tester.pump();
      } else if (missing == 'closed') {
        await tester.runAsync(source.close);
        expect(source.isClosed, isTrue);
      }
      await goPreview(tester, bloc: source);
      expect(find.textContaining('No PDF is available'), findsOneWidget);
      expect(renderer.reports, isEmpty);
      if (missing == 'loading') {
        pending.complete(Right(report));
        await tester.pumpAndSettle();
      }
    });
  }

  widgetCase('empty PDF data does not invoke the renderer', (tester) async {
    generate.handler = (_) async => Right(PdfReport(bytes: const []));
    await launch(tester);
    await open(tester);
    expect(find.textContaining('contains no data'), findsOneWidget);
    expect(renderer.reports, isEmpty);
  });

  widgetCase(
    'an invalid UUID cannot preview even a matching in-memory success',
    (
      tester,
    ) async {
      await launch(tester);
      final source = blocs.single
        ..add(const ReportRequested(runId: 'unsaved-result'));
      await tester.pump();
      await tester.pump();
      expect(source.state, isA<ReportSuccess>());
      await goPreview(
        tester,
        pathId: 'unsaved-result',
        sourceId: 'unsaved-result',
        bloc: source,
      );
      expect(find.textContaining('No PDF is available'), findsOneWidget);
      expect(renderer.reports, isEmpty);
    },
  );

  widgetCase(
    'leaving detail and returning follows the existing transient state',
    (
      tester,
    ) async {
      await launch(tester);
      await open(tester);
      final previous = blocs.single;
      router.router.go(AppRoutes.history);
      await tester.pumpAndSettle();
      expect(previous.isClosed, isTrue);
      router.router.go(AppRoutes.historyDetail(runId));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_preview_button')), findsNothing);
      expect(find.byKey(const Key('report_ready')), findsNothing);
      expect(find.byKey(const Key('report_generate_button')), findsOneWidget);
      expect(generate.ids, [runId]);
    },
  );

  widgetCase(
    'absent filename stays absent instead of inventing server metadata',
    (
      tester,
    ) async {
      final unnamed = PdfReport(bytes: const [4, 5]);
      generate.handler = (_) async => Right(unnamed);
      await launch(tester);
      await open(tester);
      expect(find.byKey(const Key('report_preview_filename')), findsNothing);
      expect(renderer.reports.single, same(unnamed));
      expect(find.text('numlab-report.pdf'), findsNothing);
    },
  );

  widgetCase(
    'viewer loading and rendering errors leave a working back action',
    (
      tester,
    ) async {
      renderer.child = const ReportPreviewLoading();
      await launch(tester);
      await tap(tester, 'report_generate_button');
      await tap(tester, 'report_preview_button');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Opening PDF…'), findsOneWidget);
      await tap(tester, 'report_preview_back');
      await tester.pumpAndSettle();
      renderer.child = const ReportPreviewMessage(
        message: 'This PDF could not be displayed.',
      );
      await tap(tester, 'report_preview_button');
      await tester.pumpAndSettle();
      expect(find.text('This PDF could not be displayed.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, 'report_preview_back');
      await tester.pumpAndSettle();
      await tap(tester, 'report_save_button');
      expect(delivery.reports.single, same(report));
      expect(generate.ids, [runId]);
    },
  );

  widgetCase(
    'logout removes private preview and follows the existing auth guard',
    (
      tester,
    ) async {
      await launch(tester);
      await open(tester);
      auth.change(const AuthUnauthenticated());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_preview_screen')), findsNothing);
      expect(find.text('Rendered PDF'), findsNothing);
      expect(
        router.router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.login,
      );
      expect(generate.ids, [runId]);
    },
  );

  widgetCase('switching accounts while previewing removes the previous PDF', (
    tester,
  ) async {
    await launch(tester);
    await open(tester);
    auth.change(
      AuthAuthenticated(
        user: User(
          id: 'another-account',
          email: 'other@example.com',
          emailVerified: true,
          createdAt: DateTime(2026),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rendered PDF'), findsNothing);
    expect(find.textContaining('No PDF is available'), findsOneWidget);
  });

  widgetCase(
    'a refreshed/deep-linked preview has no PDF and never generates one',
    (
      tester,
    ) async {
      router.dispose();
      router = AppRouter(
        authBloc: auth,
        initialLocation: AppRoutes.reportPreview(runId),
      );
      await launch(tester);
      expect(find.textContaining('No PDF is available'), findsOneWidget);
      expect(renderer.reports, isEmpty);
      expect(generate.ids, isEmpty);
      await tap(tester, 'report_preview_back');
      await tester.pumpAndSettle();
      expect(
        router.router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.historyDetail(runId),
      );
    },
  );

  widgetCase(
    'an old preview callback cannot borrow a newly signed-in account',
    (
      tester,
    ) async {
      await launch(tester);
      await tap(tester, 'report_generate_button');
      final previousTap = tester
          .widget<OutlinedButton>(
            find.byKey(const Key('report_preview_button')),
          )
          .onPressed!;
      auth.change(
        AuthAuthenticated(
          user: User(
            id: 'another-account',
            email: 'other@example.com',
            emailVerified: true,
            createdAt: DateTime(2026),
          ),
        ),
      );
      // Invoke before the pending auth-driven rebuild, like a queued tap.
      previousTap();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_preview_screen')), findsNothing);
      expect(renderer.reports, isEmpty);
      expect(generate.ids, [runId]);
    },
  );

  for (final ineligible in ['guest', 'unsaved', 'unauthorized']) {
    widgetCase('$ineligible calculation has no preview workflow', (
      tester,
    ) async {
      if (ineligible == 'guest') auth.change(const AuthUnauthenticated());
      history.current = HistoryDetailLoaded(
        run: savedRun(
          id: ineligible == 'unsaved' ? 'not-a-persisted-uuid' : runId,
          owner: ineligible == 'unauthorized' ? 'other' : 'student',
        ),
      );
      await launch(tester);
      expect(find.byKey(const Key('report_preview_button')), findsNothing);
      expect(generate.ids, isEmpty);
      expect(renderer.reports, isEmpty);
    });
  }

  for (final dark in [false, true]) {
    widgetCase('320px preview metadata/back layout fits (dark: $dark)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      generate.handler = (_) async => Right(
        PdfReport(
          bytes: const [1, 2],
          filename: '${'long-filename-' * 30}.pdf',
        ),
      );
      await launch(tester, dark: dark);
      await open(tester);
      expect(find.text('Rendered PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

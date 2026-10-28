import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/theme/app_theme.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_run.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/presentation/pages/history_detail_page.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/domain/usecases/generate_report_use_case.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/report_delivery_bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';
import 'package:numlab_frontend/features/reports/presentation/widgets/report_actions.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_result_view.dart';
import 'package:numlab_frontend/injection_container.dart';

class TestAuth extends Fake implements AuthBloc {
  TestAuth(this.current);
  AuthState current;
  final controller = StreamController<AuthState>.broadcast();
  @override
  AuthState get state => current;
  @override
  Stream<AuthState> get stream => controller.stream;
  void change(AuthState value) {
    current = value;
    controller.add(value);
  }

  @override
  Future<void> close() => controller.close();
}

class TestHistory extends Fake implements HistoryBloc {
  TestHistory(HistoryRun run) : current = HistoryDetailLoaded(run: run);
  HistoryState current;
  final controller = StreamController<HistoryState>.broadcast();
  @override
  HistoryState get state => current;
  @override
  Stream<HistoryState> get stream => controller.stream;
  @override
  void add(HistoryEvent event) => fail('Loaded history should not fetch again');
  @override
  Future<void> close() => controller.close();
}

class TestGenerate extends Fake implements GenerateReportUseCase {
  final ids = <String>[];
  late Future<Either<Failure, PdfReport>> Function(String) handler;
  @override
  Future<Either<Failure, PdfReport>> call(String id) {
    ids.add(id);
    return handler(id);
  }
}

class TestDelivery extends Fake implements ReportDelivery {
  final reports = <PdfReport>[];
  late Future<ReportDeliveryOutcome> Function() handler;
  @override
  Future<ReportDeliveryOutcome> save(PdfReport report) {
    reports.add(report);
    return handler();
  }
}

void main() {
  const runId = '550e8400-e29b-41d4-a716-446655440000';
  const nextId = '550e8400-e29b-41d4-a716-446655440001';
  final user = User(
    id: 'student',
    email: 'test@example.com',
    emailVerified: true,
    createdAt: DateTime(2026),
  );
  final report = PdfReport(
    bytes: const [0x25, 0x50, 0xff],
    filename: 'server.pdf',
  );
  late TestAuth auth;
  late TestGenerate generate;
  late TestDelivery delivery;
  late List<ReportBloc> created;
  final histories = <TestHistory>[];

  HistoryRun savedRun({String id = runId, String? owner = 'student'}) =>
      HistoryRun(
        id: id,
        userId: owner,
        method: 'root/bisection',
        createdAt: DateTime(2026),
        outputPayload: const {
          'method': 'Bisection Method',
          'finalAnswer': {'root': 2.0},
          'status': 'converged',
        },
      );

  setUp(() async {
    await sl.reset();
    generate = TestGenerate()..handler = (_) async => Right(report);
    delivery = TestDelivery()
      ..handler = () async => ReportDeliveryOutcome.saved;
    created = [];
    sl
      ..registerFactory<ReportBloc>(() {
        final bloc = ReportBloc(generateReportUseCase: generate);
        created.add(bloc);
        return bloc;
      })
      ..registerFactory<ReportDeliveryBloc>(
        () => ReportDeliveryBloc(delivery: delivery),
      );
  });
  tearDown(() async {
    await sl.reset();
  });

  void widgetCase(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      auth = TestAuth(AuthAuthenticated(user: user));
      histories.clear();
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await auth.close();
        for (final history in histories) {
          await history.close();
        }
      }
    });
  }

  Future<void> pumpRun(
    WidgetTester tester,
    HistoryRun run, {
    bool history = false,
    bool withAuth = true,
    bool dark = false,
  }) async {
    Widget child = ReportActions(run: run);
    if (history) {
      final source = TestHistory(run);
      histories.add(source);
      child = HistoryDetailPage(runId: run.id, bloc: source);
    } else {
      child = Scaffold(body: SingleChildScrollView(child: child));
    }
    child = MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: child,
    );
    if (withAuth) {
      child = BlocProvider<AuthBloc>.value(value: auth, child: child);
    }
    await tester.pumpWidget(child);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump();
  }

  widgetCase(
    'eligible history detail requests its actual persisted ID and preserves solver result',
    (tester) async {
      await pumpRun(tester, savedRun(), history: true);
      expect(find.byType(SolverResultView), findsOneWidget);
      await tap(tester, 'report_generate_button');
      expect(generate.ids, [runId]);
      expect(find.byKey(const Key('report_ready')), findsOneWidget);
      expect(delivery.reports, isEmpty);
      await tap(tester, 'report_save_button');
      expect(delivery.reports.single, same(report));
      expect(delivery.reports.single.bytes, same(report.bytes));
      expect(delivery.reports.single.filename, 'server.pdf');
      expect(find.text('PDF saved.'), findsOneWidget);
    },
  );

  for (final run in [
    savedRun(id: ''),
    savedRun(id: 'not-a-persisted-uuid'),
    savedRun(owner: null),
    savedRun(owner: 'someone-else'),
  ]) {
    widgetCase(
      'ineligible run has no report action (${run.id}/${run.userId})',
      (tester) async {
        await pumpRun(tester, run);
        expect(find.byKey(const Key('report_generate_button')), findsNothing);
        expect(generate.ids, isEmpty);
        expect(delivery.reports, isEmpty);
      },
    );
  }
  widgetCase('guest history context has no report action', (tester) async {
    auth.current = const AuthUnauthenticated();
    await pumpRun(tester, savedRun());
    expect(find.byKey(const Key('report_actions')), findsNothing);
    expect(generate.ids, isEmpty);
  });
  widgetCase('standalone context without AuthBloc has no report action', (
    tester,
  ) async {
    await pumpRun(tester, savedRun(), withAuth: false);
    expect(find.byKey(const Key('report_actions')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  widgetCase(
    'live solver result without persisted ID does not offer report generation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SolverResultView(
                result: SolverResult(
                  method: 'Bisection Method',
                  finalAnswer: {'root': 2.0},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('report_actions')), findsNothing);
      expect(find.byType(SolverResultView), findsOneWidget);
    },
  );
  widgetCase(
    'loading is immediate and repeated taps cannot create duplicate requests',
    (tester) async {
      final pending = Completer<Either<Failure, PdfReport>>();
      generate.handler = (_) => pending.future;
      await pumpRun(tester, savedRun());
      await tap(tester, 'report_generate_button');
      expect(find.text('Generating PDF…'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('report_generate_button')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('report_generate_button')));
      await tester.pump();
      expect(generate.ids, [runId]);
      pending.complete(Right(report));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('report_ready')), findsOneWidget);
    },
  );

  final errors = <Failure>[
    const ServerFailure(message: 'private-token/raw-response'),
    const ServerFailure(message: 'private-token/raw-response', statusCode: 404),
    const AuthFailure(message: 'private-token'),
    const ValidationFailure(message: 'private-token'),
    const NetworkFailure(message: 'private-token'),
    const NetworkFailure(message: 'private-token', code: 'REQUEST_TIMEOUT'),
    const RateLimitFailure(message: 'private-token', retryAfterSeconds: 30),
    const RateLimitFailure(message: 'private-token'),
  ];
  for (final error in errors) {
    widgetCase(
      'generation error is safe and manually recoverable (${error.runtimeType}/${error.code}/${error.props})',
      (tester) async {
        generate.handler = (_) async => Left(error);
        await pumpRun(tester, savedRun());
        await tap(tester, 'report_generate_button');
        expect(
          find.byKey(const Key('report_generation_error')),
          findsOneWidget,
        );
        expect(find.textContaining('private-token'), findsNothing);
        expect(find.text('Retry report'), findsOneWidget);
        expect(delivery.reports, isEmpty);
        generate.handler = (_) async => Right(report);
        await tap(tester, 'report_generate_button');
        expect(generate.ids, [runId, runId]);
        expect(find.byKey(const Key('report_ready')), findsOneWidget);
        expect(find.byKey(const Key('report_generation_error')), findsNothing);
      },
    );
  }

  widgetCase(
    'cancelled save keeps PDF ready and retry does not regenerate it',
    (tester) async {
      delivery.handler = () async => ReportDeliveryOutcome.cancelled;
      await pumpRun(tester, savedRun());
      await tap(tester, 'report_generate_button');
      await tap(tester, 'report_save_button');
      expect(
        find.text('Save cancelled. The PDF is still ready.'),
        findsOneWidget,
      );
      expect(find.text('PDF saved.'), findsNothing);
      delivery.handler = () async => ReportDeliveryOutcome.saved;
      await tap(tester, 'report_save_button');
      expect(generate.ids, [runId]);
      expect(delivery.reports, [report, report]);
      expect(find.text('PDF saved.'), findsOneWidget);
    },
  );
  widgetCase(
    'file errors are separate from generation and retry does not claim early success',
    (tester) async {
      delivery.handler = () async =>
          throw Exception('private filesystem/path token');
      await pumpRun(tester, savedRun());
      await tap(tester, 'report_generate_button');
      await tap(tester, 'report_save_button');
      expect(
        find.text('Could not save the PDF. Please try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('report_generation_error')), findsNothing);
      expect(find.textContaining('private filesystem'), findsNothing);
      expect(find.text('PDF saved.'), findsNothing);
      delivery.handler = () async => ReportDeliveryOutcome.saved;
      await tap(tester, 'report_save_button');
      expect(generate.ids, [runId]);
      expect(find.text('PDF saved.'), findsOneWidget);
    },
  );
  widgetCase('browser handoff never claims confirmed persistence', (
    tester,
  ) async {
    delivery.handler = () async => ReportDeliveryOutcome.downloadRequested;
    await pumpRun(tester, savedRun());
    await tap(tester, 'report_generate_button');
    await tap(tester, 'report_save_button');
    expect(
      find.text('Download requested. Check your browser downloads.'),
      findsOneWidget,
    );
    expect(find.text('PDF saved.'), findsNothing);
  });
  widgetCase('pending save disables duplicate file operations', (tester) async {
    final pending = Completer<ReportDeliveryOutcome>();
    delivery.handler = () => pending.future;
    await pumpRun(tester, savedRun());
    await tap(tester, 'report_generate_button');
    await tap(tester, 'report_save_button');
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('report_save_button')))
          .onPressed,
      isNull,
    );
    expect(find.text('PDF saved.'), findsNothing);
    await tester.tap(find.byKey(const Key('report_save_button')));
    await tester.pump();
    expect(delivery.reports, hasLength(1));
    pending.complete(ReportDeliveryOutcome.saved);
    await tester.pump();
    await tester.pump();
    expect(find.text('PDF saved.'), findsOneWidget);
  });
  widgetCase(
    'switching runs closes the old workflow and ignores late report success',
    (tester) async {
      final pending = Completer<Either<Failure, PdfReport>>();
      generate.handler = (_) => pending.future;
      await pumpRun(tester, savedRun());
      await tap(tester, 'report_generate_button');
      final old = created.single;
      await pumpRun(tester, savedRun(id: nextId));
      pending.complete(Right(report));
      await tester.pump();
      await tester.pump();
      expect(old.isClosed, isTrue);
      expect(find.byKey(const Key('report_ready')), findsNothing);
      generate.handler = (_) async => Right(report);
      await tap(tester, 'report_generate_button');
      expect(generate.ids, [runId, nextId]);
      expect(find.byKey(const Key('report_ready')), findsOneWidget);
    },
  );
  widgetCase(
    'logout during generation hides the action and a later login starts clean',
    (tester) async {
      final pending = Completer<Either<Failure, PdfReport>>();
      generate.handler = (_) => pending.future;
      await pumpRun(tester, savedRun());
      await tap(tester, 'report_generate_button');
      auth.change(const AuthUnauthenticated());
      await tester.pump();
      await tester.pump();
      pending.complete(Right(report));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('report_actions')), findsNothing);
      expect(delivery.reports, isEmpty);
      auth.change(AuthAuthenticated(user: user));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('report_ready')), findsNothing);
      expect(find.byKey(const Key('report_generate_button')), findsOneWidget);
    },
  );
  widgetCase(
    'switching runs during a save cannot publish the previous saved status',
    (tester) async {
      final pending = Completer<ReportDeliveryOutcome>();
      delivery.handler = () => pending.future;
      await pumpRun(tester, savedRun());
      await tap(tester, 'report_generate_button');
      await tap(tester, 'report_save_button');
      await pumpRun(tester, savedRun(id: nextId));
      await tap(tester, 'report_generate_button');
      pending.complete(ReportDeliveryOutcome.saved);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('report_ready')), findsOneWidget);
      expect(find.text('PDF saved.'), findsNothing);
      expect(find.byKey(const Key('report_delivery_message')), findsNothing);
      expect(generate.ids, [runId, nextId]);
      expect(delivery.reports, hasLength(1));
    },
  );
  widgetCase(
    'leaving while pending and returning starts with a fresh report BLoC',
    (tester) async {
      final pending = Completer<Either<Failure, PdfReport>>();
      generate.handler = (_) => pending.future;
      await pumpRun(tester, savedRun());
      await tap(tester, 'report_generate_button');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Home'))),
      );
      await tester.pump();
      pending.complete(Right(report));
      await tester.pump();
      await tester.pump();
      await pumpRun(tester, savedRun());
      expect(find.byKey(const Key('report_ready')), findsNothing);
      expect(created.first.isClosed, isTrue);
      expect(generate.ids, [runId]);
    },
  );
  for (final dark in [false, true]) {
    widgetCase(
      '320px production theme renders report errors/save controls without overflow (dark: $dark)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        generate.handler = (_) async => const Left(
          RateLimitFailure(message: 'quota', retryAfterSeconds: 900),
        );
        await pumpRun(tester, savedRun(), dark: dark);
        await tap(tester, 'report_generate_button');
        expect(find.textContaining('900 seconds'), findsOneWidget);
        expect(tester.takeException(), isNull);
        generate.handler = (_) async => Right(report);
        await tap(tester, 'report_generate_button');
        await tap(tester, 'report_save_button');
        expect(find.text('PDF saved.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

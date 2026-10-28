import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_theme.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/data/models/models.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/presentation/pages/pages.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/charts.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_explanation_view.dart';

class MockHistoryBloc extends Fake implements HistoryBloc {
  MockHistoryBloc([HistoryState initialState = const HistoryInitial()]) {
    _state = initialState;
  }

  late HistoryState _state;
  final StreamController<HistoryState> _controller =
      StreamController<HistoryState>.broadcast();
  final List<HistoryEvent> recordedEvents = [];

  @override
  HistoryState get state => _state;

  @override
  Stream<HistoryState> get stream => _controller.stream;

  @override
  void add(HistoryEvent event) {
    recordedEvents.add(event);
  }

  void emitState(HistoryState newState) {
    _state = newState;
    _controller.add(newState);
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

class MockAuthBloc extends Fake implements AuthBloc {
  MockAuthBloc(this._initialState) {
    _state = _initialState;
  }

  final AuthState _initialState;
  late AuthState _state;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  group('HistoryDetailPage presentation tests', () {
    testWidgets(
      'history shows deterministic and saved AI explanations together',
      (tester) async {
        final run = HistoryRun(
          id: 'both-explanations',
          method: 'root/bisection',
          createdAt: DateTime(2026, 10, 27),
          outputPayload: const {
            'method': 'Bisection Method',
            'status': 'converged',
            'finalAnswer': {'root': 2},
            'explanation': {
              'summary': 'Deterministic steps',
              'steps': <String>[],
            },
          },
          aiExplanations: [
            HistoryExplanation(
              id: 'saved-ai',
              responseText: '**Saved tutor** explanation.',
              createdAt: DateTime(2026, 10, 27),
            ),
          ],
        );
        final bloc = MockHistoryBloc(HistoryDetailLoaded(run: run));
        addTearDown(bloc.close);
        await tester.pumpWidget(
          MaterialApp(
            home: HistoryDetailPage(runId: run.id, bloc: bloc),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Deterministic steps'), findsOneWidget);
        expect(find.text('Saved tutor explanation.'), findsOneWidget);
        expect(find.text('Saved AI Explanation'), findsOneWidget);
        expect(find.byType(SolverExplanationView), findsNWidgets(2));
        expect(find.byKey(const Key('explanation_cached_chip')), findsNothing);
        expect(find.byKey(const Key('explanation_fresh_chip')), findsNothing);
        expect(bloc.recordedEvents, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    late MockHistoryBloc mockHistoryBloc;

    final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');

    final tRun = HistoryRun(
      id: 'test-run-123',
      method: 'root/bisection',
      createdAt: timestamp,
      inputPayload: const {
        'equation': 'x^2 - 4',
        'a': 0.0,
        'b': 3.0,
        'tolerance': 0.001,
      },
      outputPayload: const {
        'method': 'Bisection Method',
        'status': 'converged',
        'finalAnswer': {
          'root': 2.0,
          'converged': true,
          'iterations': 12,
          'error': 0.000488,
        },
        'iterations': [
          {'iteration': 1, 'a': 0.0, 'b': 3.0, 'midpoint': 1.5},
          {'iteration': 2, 'a': 1.5, 'b': 3.0, 'midpoint': 2.25},
        ],
        'warnings': ['Approaching boundary of bracket'],
        'executionTimeMs': 14,
      },
    );

    final tRunWithExplanation = HistoryRun(
      id: 'test-run-exp',
      method: 'ode/euler',
      createdAt: timestamp,
      inputPayload: const {'equation': 'x + y'},
      outputPayload: const {
        'method': 'Euler Method',
        'status': 'completed',
        'finalAnswer': {'y': 3.5},
      },
      aiExplanations: [
        HistoryExplanation(
          id: 'exp-1',
          responseText:
              'Euler method approximates the solution curve by stepping forward along the tangent vector.',
          createdAt: timestamp,
        ),
      ],
    );

    final tRunWithGraphData = HistoryRun(
      id: 'test-run-graph',
      method: 'root/bisection',
      createdAt: timestamp,
      inputPayload: const {'equation': 'x^2 - 4'},
      outputPayload: const {
        'method': 'Bisection Method',
        'status': 'converged',
        'finalAnswer': {'root': 2.0, 'converged': true},
        'graphData': {
          'type': 'curve',
          'points': [
            {'x': 0.0, 'y': -4.0},
            {'x': 1.0, 'y': -3.0},
            {'x': 2.0, 'y': 0.0},
            {'x': 3.0, 'y': 5.0},
          ],
          'label': 'f(x) = x^2 - 4',
        },
      },
    );

    setUp(() {
      mockHistoryBloc = MockHistoryBloc();
    });

    tearDown(() async {
      await mockHistoryBloc.close();
    });

    Widget buildTestWidget({
      required String runId,
      required HistoryBloc bloc,
      Size size = const Size(800, 1200),
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: HistoryDetailPage(
            runId: runId,
            bloc: bloc,
          ),
        ),
      );
    }

    testWidgets(
      'renders loading indicator when state is HistoryDetailLoading',
      (
        tester,
      ) async {
        mockHistoryBloc = MockHistoryBloc(
          const HistoryDetailLoading(runId: 'test-run-123'),
        );

        await tester.pumpWidget(
          buildTestWidget(runId: 'test-run-123', bloc: mockHistoryBloc),
        );

        expect(
          find.byKey(const Key('history_detail_loading_indicator')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('history_detail_solver_result_view')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('history_detail_error_view')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'dispatches HistoryRunRequested when initialized with no existing detail',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc();

        await tester.pumpWidget(
          buildTestWidget(runId: 'test-run-123', bloc: mockHistoryBloc),
        );

        expect(
          mockHistoryBloc.recordedEvents,
          contains(const HistoryRunRequested('test-run-123')),
        );
        expect(
          find.byKey(const Key('history_detail_loading_indicator')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders SolverResultView when HistoryDetailLoaded matches runId',
      (
        tester,
      ) async {
        mockHistoryBloc = MockHistoryBloc(
          HistoryDetailLoaded(run: tRun),
        );

        await tester.pumpWidget(
          buildTestWidget(runId: 'test-run-123', bloc: mockHistoryBloc),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history_detail_solver_result_view')),
          findsOneWidget,
        );
        expect(find.text('Method: Bisection Method'), findsOneWidget);
        expect(find.text('Calculation Result'), findsOneWidget);
        expect(find.byKey(const Key('solver_result_root')), findsOneWidget);
        expect(find.text('Root: 2.0'), findsOneWidget);
        expect(find.text('Time: 14 ms'), findsOneWidget);
        expect(find.text('Iterations: 12'), findsOneWidget);
      },
    );

    testWidgets(
      'renders error view on failure and retry button dispatches HistoryRunRequested',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          const HistoryError(
            failure: ServerFailure(
              message: 'Calculation run not found',
              statusCode: 404,
            ),
          ),
        );

        await tester.pumpWidget(
          buildTestWidget(runId: 'test-run-123', bloc: mockHistoryBloc),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history_detail_error_view')),
          findsOneWidget,
        );
        expect(find.text('Calculation run not found'), findsOneWidget);
        expect(
          find.byKey(const Key('history_detail_retry_button')),
          findsOneWidget,
        );

        // Tap retry
        await tester.tap(find.byKey(const Key('history_detail_retry_button')));
        await tester.pump();

        expect(
          mockHistoryBloc.recordedEvents,
          contains(const HistoryRunRequested('test-run-123')),
        );
      },
    );

    testWidgets(
      'HistoryRun.toSolverResult converts all core properties faithfully',
      (
        tester,
      ) async {
        final solverResult = tRun.toSolverResult();

        expect(solverResult, isA<SolverResult>());
        expect(solverResult.method, 'Bisection Method');
        expect(solverResult.status, 'converged');
        expect(solverResult.isConverged, isTrue);
        expect(solverResult.root, 2.0);
        expect(solverResult.iterationsCount, 12);
        expect(solverResult.executionTimeMs, 14);
        expect(
          solverResult.warnings,
          contains('Approaching boundary of bracket'),
        );
        expect(solverResult.requestId, 'test-run-123');
        expect(solverResult.iterations.length, 2);
      },
    );

    testWidgets(
      'attached AI explanation is preserved and rendered via SolverExplanationView',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          HistoryDetailLoaded(run: tRunWithExplanation),
        );

        await tester.pumpWidget(
          buildTestWidget(runId: 'test-run-exp', bloc: mockHistoryBloc),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SolverExplanationView), findsOneWidget);
        expect(
          find.textContaining('Euler method approximates the solution curve'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'historical graphData reaches existing chart pipeline and renders CurveChartRenderer',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          HistoryDetailLoaded(run: tRunWithGraphData),
        );

        await tester.pumpWidget(
          buildTestWidget(
            runId: 'test-run-graph',
            bloc: mockHistoryBloc,
            size: const Size(800, 1400),
          ),
        );
        await tester.pumpAndSettle();

        // Verifies chart component hierarchy is reused directly
        expect(find.byType(SolverChartView), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_view')), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_title')), findsOneWidget);
        expect(find.text('Bisection Method Graph'), findsOneWidget);
        expect(find.byType(LineChart), findsOneWidget);
      },
    );

    testWidgets(
      'HistoryRunModel.toSolverResult populates typedGraphData and solution fallbacks',
      (tester) async {
        final model = HistoryRunModel(
          id: 'model-run-1',
          method: 'linear/gauss',
          createdAt: timestamp,
          outputPayload: const {
            'solution': [1.0, -2.0, 3.0],
            'graphData': {
              'type': 'curve',
              'points': [
                {'x': 0.0, 'y': 1.0},
              ],
            },
          },
        );

        final result = model.toSolverResult();

        expect(result.method, 'linear/gauss');
        expect(result.finalAnswer['solution'], [1.0, -2.0, 3.0]);
        expect(result.solutionVector, [1.0, -2.0, 3.0]);
        expect(result.hasGraphData, isTrue);
        expect(result.typedGraphData, isNotNull);
      },
    );

    testWidgets('back button triggers navigation back', (tester) async {
      mockHistoryBloc = MockHistoryBloc(
        HistoryDetailLoaded(run: tRun),
      );

      final router = GoRouter(
        initialLocation: '/history/test-run-123',
        routes: [
          GoRoute(
            path: '/history',
            builder: (context, state) => const Scaffold(
              key: Key('mock_history_list_screen'),
            ),
            routes: [
              GoRoute(
                path: ':runId',
                builder: (context, state) => HistoryDetailPage(
                  runId: state.pathParameters['runId'] ?? '',
                  bloc: mockHistoryBloc,
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('history_detail_solver_result_view')),
        findsOneWidget,
      );

      final backButton = find.byKey(const Key('history_detail_back_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mock_history_list_screen')), findsOneWidget);
      expect(
        find.byKey(const Key('history_detail_solver_result_view')),
        findsNothing,
      );
    });

    testWidgets('tapping HistoryListItem navigates to /history/:runId route', (
      tester,
    ) async {
      mockHistoryBloc = MockHistoryBloc(
        HistoryLoaded(
          runs: [tRun],
          pagination: const Pagination(
            total: 1,
            limit: 20,
            offset: 0,
            hasMore: false,
          ),
        ),
      );

      final router = GoRouter(
        initialLocation: '/history',
        routes: [
          GoRoute(
            path: '/history',
            builder: (context, state) => HistoryPage(bloc: mockHistoryBloc),
            routes: [
              GoRoute(
                path: ':runId',
                builder: (context, state) => HistoryDetailPage(
                  runId: state.pathParameters['runId'] ?? '',
                  bloc: mockHistoryBloc,
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();

      final listItemFinder = find.byKey(Key('history_item_${tRun.id}'));
      expect(listItemFinder, findsOneWidget);

      await tester.tap(listItemFinder);
      await tester.pump();
      mockHistoryBloc.emitState(HistoryDetailLoaded(run: tRun));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('history_detail_screen')),
        findsOneWidget,
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        '/history/${tRun.id}',
      );
    });

    testWidgets(
      'invalid or empty runId renders invalid id view without dispatching request',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc();

        await tester.pumpWidget(
          buildTestWidget(runId: '   ', bloc: mockHistoryBloc),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history_detail_invalid_id_view')),
          findsOneWidget,
        );
        expect(find.text('Invalid calculation ID.'), findsOneWidget);
        expect(
          find.byKey(const Key('history_detail_back_to_history_button')),
          findsOneWidget,
        );
        expect(mockHistoryBloc.recordedEvents, isEmpty);
      },
    );

    testWidgets(
      'tapping Back to History on invalid id view navigates back to /history',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc();

        final router = GoRouter(
          initialLocation: '/history/   ',
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const Scaffold(
                key: Key('mock_history_list_screen'),
              ),
              routes: [
                GoRoute(
                  path: ':runId',
                  builder: (context, state) => HistoryDetailPage(
                    runId: state.pathParameters['runId'] ?? '',
                    bloc: mockHistoryBloc,
                  ),
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history_detail_invalid_id_view')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('history_detail_back_to_history_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('mock_history_list_screen')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'rebuilding when already loading does not duplicate HistoryRunRequested',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          const HistoryDetailLoading(runId: 'test-run-123'),
        );

        await tester.pumpWidget(
          buildTestWidget(runId: 'test-run-123', bloc: mockHistoryBloc),
        );
        await tester.pump();

        expect(mockHistoryBloc.recordedEvents, isEmpty);
      },
    );
  });

  group('AppRouter History Detail Route Tests', () {
    late MockAuthBloc mockAuthBloc;
    late AppRouter appRouter;

    final tUser = User(
      id: 'student-uuid',
      email: 'student@example.com',
      emailVerified: true,
      createdAt: DateTime.parse('2026-09-26T12:00:00.000Z'),
    );

    tearDown(() async {
      appRouter.dispose();
      await mockAuthBloc.close();
    });

    testWidgets(
      'Unauthenticated → /history/:runId redirects to /login with encoded destination',
      (tester) async {
        mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: '/history/abc-123-uuid',
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('login_screen')), findsOneWidget);
        expect(find.byKey(const Key('history_detail_screen')), findsNothing);

        final currentUri = appRouter.router.routeInformationProvider.value.uri;
        expect(currentUri.path, AppRoutes.login);
        expect(
          currentUri.queryParameters['from'],
          '/history/abc-123-uuid',
        );
      },
    );

    testWidgets(
      'Authenticated → /history/:runId resolves and passes runId correctly',
      (tester) async {
        mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: '/history/run-xyz-789',
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('history_detail_screen')), findsOneWidget);
        expect(find.byKey(const Key('login_screen')), findsNothing);
      },
    );
  });
}

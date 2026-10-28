import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/history/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/presentation/pages/pages.dart';
import 'package:numlab_frontend/features/profile/presentation/profile_screen.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_result_view.dart';

class MockGetHistoryRunsUseCase extends Fake implements GetHistoryRunsUseCase {
  Future<Either<Failure, PaginatedHistory>> Function({
    int limit,
    int offset,
  })?
  handler;

  @override
  Future<Either<Failure, PaginatedHistory>> call({
    int limit = 20,
    int offset = 0,
  }) async => handler!(limit: limit, offset: offset);
}

class MockGetHistoryRunByIdUseCase extends Fake
    implements GetHistoryRunByIdUseCase {
  Future<Either<Failure, HistoryRun>> Function(String runId)? handler;

  @override
  Future<Either<Failure, HistoryRun>> call(String runId) async =>
      handler!(runId);
}

class MockAuthBloc extends Fake implements AuthBloc {
  MockAuthBloc(this._state);

  final AuthState _state;

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => Stream.value(_state);

  @override
  Future<void> close() async {}
}

class MockHistoryBloc extends Fake implements HistoryBloc {
  MockHistoryBloc([HistoryState initialState = const HistoryInitial()]) {
    _state = initialState;
  }

  late HistoryState _state;
  final StreamController<HistoryState> _controller =
      StreamController<HistoryState>.broadcast();
  final List<HistoryEvent> recordedEvents = [];
  void Function(HistoryEvent event)? onAdd;

  @override
  HistoryState get state => _state;

  @override
  Stream<HistoryState> get stream => _controller.stream;

  @override
  void add(HistoryEvent event) {
    recordedEvents.add(event);
    onAdd?.call(event);
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

void main() {
  group('20+ Solves Verification & Profile Flow Tests (Phase 4h)', () {
    late MockGetHistoryRunsUseCase mockGetHistoryRunsUseCase;
    late MockGetHistoryRunByIdUseCase mockGetHistoryRunByIdUseCase;
    late HistoryBloc historyBloc;

    final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');

    // Create 25 distinct calculation runs (indices 0 to 24)
    final all25Runs = List<HistoryRun>.generate(25, (index) {
      return HistoryRun(
        id: 'run-$index',
        method: index.isEven ? 'root/bisection' : 'root/newton-raphson',
        createdAt: timestamp.add(Duration(minutes: index)),
        inputPayload: {'equation': 'x^2 - $index'},
        outputPayload: {
          'method': index.isEven ? 'Bisection Method' : 'Newton-Raphson Method',
          'status': 'converged',
          'finalAnswer': {
            'root': 1.0 + (index * 0.1),
            'iterations': 5 + (index % 5),
            'converged': true,
          },
          'executionTimeMs': 10 + index,
        },
      );
    });

    // Page 1: 20 runs (indices 0..19), total: 25, hasMore: true
    final page1Runs = all25Runs.sublist(0, 20);
    const paginationPage1 = Pagination(
      total: 25,
      limit: 20,
      offset: 0,
      hasMore: true,
    );
    final paginatedPage1 = PaginatedHistory(
      runs: page1Runs,
      pagination: paginationPage1,
    );

    // Page 2: 5 runs (indices 20..24), total: 25, hasMore: false
    final page2Runs = all25Runs.sublist(20, 25);
    const paginationPage2 = Pagination(
      total: 25,
      limit: 20,
      offset: 20,
      hasMore: false,
    );
    final paginatedPage2 = PaginatedHistory(
      runs: page2Runs,
      pagination: paginationPage2,
    );

    setUp(() {
      mockGetHistoryRunsUseCase = MockGetHistoryRunsUseCase();
      mockGetHistoryRunByIdUseCase = MockGetHistoryRunByIdUseCase();
      historyBloc = HistoryBloc(
        getHistoryRunsUseCase: mockGetHistoryRunsUseCase,
        getHistoryRunByIdUseCase: mockGetHistoryRunByIdUseCase,
      );
    });

    tearDown(() async {
      await historyBloc.close();
    });

    test(
      'first page loads 20 runs, reports total == 25, and hasMore == true',
      () async {
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async {
              expect(limit, 20);
              expect(offset, 0);
              return Right<Failure, PaginatedHistory>(paginatedPage1);
            };

        historyBloc.add(const HistoryLoadRequested());
        await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

        final loadedState = historyBloc.state as HistoryLoaded;
        expect(loadedState.runs.length, 20);
        expect(loadedState.pagination.total, 25);
        expect(loadedState.pagination.hasMore, isTrue);
        expect(loadedState.runs.first.id, 'run-0');
        expect(loadedState.runs.last.id, 'run-19');
      },
    );

    testWidgets(
      'Profile history summary uses pagination.total (25), not returned page count (1)',
      (tester) async {
        // Summary requests limit: 1 to minimize payload
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async {
              expect(limit, 1);
              return const Right<Failure, PaginatedHistory>(
                PaginatedHistory(
                  runs: [],
                  pagination: Pagination(
                    total: 25,
                    limit: 1,
                    offset: 0,
                    hasMore: true,
                  ),
                ),
              );
            };

        final tUser = User(
          id: 'test-user-uuid',
          email: 'student@numlab.ai',
          emailVerified: true,
          createdAt: timestamp,
        );

        final authBloc = MockAuthBloc(AuthAuthenticated(user: tUser));

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: ProfileScreen(
                getHistoryRunsUseCase: mockGetHistoryRunsUseCase,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_history_card')), findsOneWidget);
        expect(find.text('Total Solves: 25'), findsOneWidget);
      },
    );

    test(
      'load-more beyond 20 runs appends 5 runs to reach 25 without duplicate IDs',
      () async {
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async {
              if (offset == 0) {
                return Right<Failure, PaginatedHistory>(paginatedPage1);
              }
              if (offset == 20) {
                return Right<Failure, PaginatedHistory>(paginatedPage2);
              }
              throw UnimplementedError('Unexpected offset: $offset');
            };

        // Load initial page 1 (20 items)
        historyBloc.add(const HistoryLoadRequested());
        await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

        // Load page 2 (remaining 5 items)
        historyBloc.add(const HistoryLoadMoreRequested());
        await historyBloc.stream.firstWhere(
          (s) => s is HistoryLoaded && s.runs.length == 25,
        );

        final loadedState = historyBloc.state as HistoryLoaded;
        expect(loadedState.runs.length, 25);
        expect(loadedState.pagination.hasMore, isFalse);

        // Verify ID uniqueness
        final uniqueIds = loadedState.runs.map((r) => r.id).toSet();
        expect(uniqueIds.length, 25);
        expect(loadedState.runs[20].id, 'run-20');
        expect(loadedState.runs[24].id, 'run-24');
      },
    );

    test(
      'pagination exhaustion: subsequent load-more does not dispatch requests',
      () async {
        var callCount = 0;
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async {
              callCount++;
              if (offset == 0) {
                return Right<Failure, PaginatedHistory>(paginatedPage1);
              }
              if (offset == 20) {
                return Right<Failure, PaginatedHistory>(paginatedPage2);
              }
              return Right<Failure, PaginatedHistory>(paginatedPage2);
            };

        // Load page 1 and page 2
        historyBloc.add(const HistoryLoadRequested());
        await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

        historyBloc.add(const HistoryLoadMoreRequested());
        await historyBloc.stream.firstWhere(
          (s) => s is HistoryLoaded && s.runs.length == 25,
        );

        expect(callCount, 2);

        // Attempt 3rd load-more when hasMore is false
        historyBloc.add(const HistoryLoadMoreRequested());
        await pumpEventQueue();

        // No new network calls made
        expect(callCount, 2);
      },
    );

    test(
      'refresh after pagination resets to offset 0 and restores page 1 runs',
      () async {
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async {
              if (offset == 0) {
                return Right<Failure, PaginatedHistory>(paginatedPage1);
              }
              if (offset == 20) {
                return Right<Failure, PaginatedHistory>(paginatedPage2);
              }
              throw UnimplementedError();
            };

        // Load all 25 runs
        historyBloc.add(const HistoryLoadRequested());
        await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);
        historyBloc.add(const HistoryLoadMoreRequested());
        await historyBloc.stream.firstWhere(
          (s) => s is HistoryLoaded && s.runs.length == 25,
        );

        // Pull to refresh
        historyBloc.add(const HistoryRefreshRequested());
        await historyBloc.stream.firstWhere((s) => s is HistoryRefreshing);
        await historyBloc.stream.firstWhere(
          (s) => s is HistoryLoaded && s.runs.length == 20,
        );

        final refreshedState = historyBloc.state as HistoryLoaded;
        expect(refreshedState.runs.length, 20);
        expect(refreshedState.pagination.offset, 0);
        expect(refreshedState.pagination.hasMore, isTrue);
      },
    );

    testWidgets(
      'detail navigation works for a run beyond page 1 (run-22) and renders SolverResultView',
      (tester) async {
        final targetRun = all25Runs[22];
        final detailBloc = MockHistoryBloc(
          HistoryDetailLoaded(run: targetRun),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HistoryDetailPage(
              runId: 'run-22',
              bloc: detailBloc,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history_detail_solver_result_view')),
          findsOneWidget,
        );
        expect(find.byType(SolverResultView), findsOneWidget);
        expect(find.text('Method: Bisection Method'), findsOneWidget);
        expect(find.text('Root: 3.2'), findsOneWidget);
        expect(find.text('Time: 32 ms'), findsOneWidget);
      },
    );

    testWidgets(
      'Profile → History summary → /history → Detail flow integration',
      (tester) async {
        final tUser = User(
          id: 'test-user-uuid',
          email: 'student@numlab.ai',
          emailVerified: true,
          createdAt: timestamp,
        );

        final authBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
        final flowHistoryBloc = MockHistoryBloc(
          HistoryLoaded(
            runs: paginatedPage1.runs,
            pagination: paginationPage1,
          ),
        );

        flowHistoryBloc.onAdd = (event) {
          if (event is HistoryRunRequested) {
            flowHistoryBloc.emitState(
              HistoryDetailLoaded(
                run: all25Runs.firstWhere((r) => r.id == event.runId),
                runs: paginatedPage1.runs,
                pagination: paginationPage1,
              ),
            );
          }
        };

        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async {
              return const Right<Failure, PaginatedHistory>(
                PaginatedHistory(
                  runs: [],
                  pagination: Pagination(
                    total: 25,
                    limit: 1,
                    offset: 0,
                    hasMore: true,
                  ),
                ),
              );
            };

        final router = GoRouter(
          initialLocation: AppRoutes.profile,
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => BlocProvider<AuthBloc>.value(
                value: authBloc,
                child: ProfileScreen(
                  getHistoryRunsUseCase: mockGetHistoryRunsUseCase,
                ),
              ),
            ),
            GoRoute(
              path: AppRoutes.history,
              builder: (context, state) => HistoryPage(bloc: flowHistoryBloc),
              routes: [
                GoRoute(
                  path: ':runId',
                  builder: (context, state) => HistoryDetailPage(
                    runId: state.pathParameters['runId'] ?? '',
                    bloc: flowHistoryBloc,
                  ),
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // 1. On Profile Screen: shows Total Solves: 25
        expect(find.byKey(const Key('profile_screen')), findsOneWidget);
        expect(find.byKey(const Key('profile_history_card')), findsOneWidget);
        expect(find.text('Total Solves: 25'), findsOneWidget);

        // 2. Tap View All to open /history
        await tester.ensureVisible(
          find.byKey(const Key('profile_history_view_all_button')),
        );
        await tester.tap(
          find.byKey(const Key('profile_history_view_all_button')),
        );
        await tester.pumpAndSettle();

        // 3. Arrives at /history, loads page 1 (20 items)
        expect(find.byKey(const Key('history_screen')), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutes.history,
        );

        // 4. Tap an item (run-2) to open detail /history/run-2
        final itemFinder = find.byKey(const Key('history_item_run-2'));
        expect(itemFinder, findsOneWidget);
        await tester.tap(itemFinder);
        await tester.pumpAndSettle();

        // 5. Arrives at /history/run-2, renders calculation result
        expect(find.byKey(const Key('history_detail_screen')), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/history/run-2',
        );
        expect(
          find.byKey(const Key('history_detail_solver_result_view')),
          findsOneWidget,
        );

        // 6. Tap back button, returns to /history
        await tester.tap(find.byKey(const Key('history_detail_back_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('history_screen')), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutes.history,
        );
      },
    );
  });
}

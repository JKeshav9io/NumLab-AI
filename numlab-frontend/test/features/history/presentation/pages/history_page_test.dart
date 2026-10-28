import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/history/presentation/pages/history_page.dart';
import 'package:numlab_frontend/features/history/presentation/widgets/history_empty_state.dart';
import 'package:numlab_frontend/features/history/presentation/widgets/history_list.dart';
import 'package:numlab_frontend/features/history/presentation/widgets/history_list_item.dart';

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

void main() {
  group('HistoryPage & Widgets', () {
    late MockHistoryBloc mockHistoryBloc;

    final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');

    final tRun1 = HistoryRun(
      id: 'run-uuid-1',
      method: 'root/bisection',
      createdAt: timestamp,
      inputPayload: const {'equation': 'x^2 - 4'},
      outputPayload: const {
        'method': 'Bisection Method',
        'status': 'converged',
        'finalAnswer': {'root': 2.0},
      },
    );

    final tRun2 = HistoryRun(
      id: 'run-uuid-2',
      method: 'ode/euler',
      createdAt: timestamp,
      inputPayload: const {'equation': 'x + y'},
      outputPayload: const {
        'method': 'Euler Method',
        'status': 'completed',
        'finalAnswer': {'y': 3.5},
      },
    );

    const tPagination = Pagination(
      total: 2,
      limit: 20,
      offset: 0,
      hasMore: false,
    );

    setUp(() {
      mockHistoryBloc = MockHistoryBloc();
    });

    tearDown(() async {
      await mockHistoryBloc.close();
    });

    Widget buildTestWidget({
      required HistoryBloc bloc,
      Size size = const Size(800, 1000),
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: HistoryPage(bloc: bloc),
        ),
      );
    }

    testWidgets('renders loading indicator when state is HistoryLoading', (
      tester,
    ) async {
      mockHistoryBloc = MockHistoryBloc(const HistoryLoading());

      await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));

      expect(
        find.byKey(const Key('history_loading_indicator')),
        findsOneWidget,
      );
      expect(find.byType(HistoryList), findsNothing);
      expect(find.byType(HistoryEmptyState), findsNothing);
    });

    testWidgets(
      'transitions dynamically from Loading to Loaded upon state emission',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(const HistoryLoading());

        await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
        expect(
          find.byKey(const Key('history_loading_indicator')),
          findsOneWidget,
        );

        mockHistoryBloc.emitState(
          HistoryLoaded(runs: [tRun1], pagination: tPagination),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history_loading_indicator')),
          findsNothing,
        );
        expect(find.byType(HistoryListItem), findsOneWidget);
      },
    );

    testWidgets(
      'renders HistoryEmptyState when state is HistoryLoaded with zero runs',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          const HistoryLoaded(
            runs: [],
            pagination: Pagination(
              total: 0,
              limit: 20,
              offset: 0,
              hasMore: false,
            ),
          ),
        );

        await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryEmptyState), findsOneWidget);
        expect(find.text('No history yet'), findsOneWidget);
        expect(find.byKey(const Key('history_empty_subtitle')), findsOneWidget);
        expect(find.byType(HistoryListItem), findsNothing);
      },
    );

    testWidgets(
      'renders error view with retry button on initial load failure',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          const HistoryError(
            failure: ServerFailure(
              message: 'Network connection failed',
              statusCode: 500,
            ),
          ),
        );

        await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('history_error_view')), findsOneWidget);
        expect(find.text('Network connection failed'), findsOneWidget);
        expect(find.byKey(const Key('history_retry_button')), findsOneWidget);

        // Tap retry
        await tester.tap(find.byKey(const Key('history_retry_button')));
        await tester.pump();

        expect(
          mockHistoryBloc.recordedEvents,
          contains(const HistoryLoadRequested()),
        );
      },
    );

    testWidgets(
      'renders list of HistoryListItem widgets when runs are loaded',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          HistoryLoaded(
            runs: [tRun1, tRun2],
            pagination: tPagination,
          ),
        );

        await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryList), findsOneWidget);
        expect(find.byType(HistoryListItem), findsNWidgets(2));
        expect(find.text('Bisection Method'), findsOneWidget);
        expect(find.text('Euler Method'), findsOneWidget);
        expect(find.text('CONVERGED'), findsOneWidget);
        expect(find.text('COMPLETED'), findsOneWidget);
      },
    );

    testWidgets('tapping history item dispatches HistoryRunRequested', (
      tester,
    ) async {
      mockHistoryBloc = MockHistoryBloc(
        HistoryLoaded(
          runs: [tRun1],
          pagination: tPagination,
        ),
      );

      await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
      await tester.pumpAndSettle();

      final itemFinder = find.byKey(Key('history_item_${tRun1.id}'));
      expect(itemFinder, findsOneWidget);

      await tester.tap(itemFinder);
      await tester.pump();

      expect(
        mockHistoryBloc.recordedEvents,
        contains(HistoryRunRequested(tRun1.id)),
      );
    });

    testWidgets('pull to refresh dispatches HistoryRefreshRequested', (
      tester,
    ) async {
      mockHistoryBloc = MockHistoryBloc(
        HistoryLoaded(
          runs: [tRun1, tRun2],
          pagination: tPagination,
        ),
      );

      await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
      await tester.pumpAndSettle();

      // Trigger pull to refresh
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        mockHistoryBloc.recordedEvents,
        contains(const HistoryRefreshRequested()),
      );
    });

    testWidgets(
      'HistoryLoadingMore keeps existing items and shows bottom indicator',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          HistoryLoadingMore(
            runs: [tRun1, tRun2],
            pagination: const Pagination(
              total: 10,
              limit: 2,
              offset: 0,
              hasMore: true,
            ),
          ),
        );

        await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
        await tester.pump();

        // Existing items remain visible
        expect(find.byType(HistoryListItem), findsNWidgets(2));
        expect(find.text('Bisection Method'), findsOneWidget);
        expect(find.text('Euler Method'), findsOneWidget);

        // Bottom loading more indicator is present
        expect(
          find.byKey(const Key('history_load_more_indicator')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows load more error retry banner and tapping retries load more',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          HistoryError(
            failure: const NetworkFailure(message: 'Timeout loading page 2'),
            runs: [tRun1, tRun2],
            pagination: const Pagination(
              total: 10,
              limit: 2,
              offset: 0,
              hasMore: true,
            ),
          ),
        );

        await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
        await tester.pumpAndSettle();

        // Existing items are preserved
        expect(find.byType(HistoryListItem), findsNWidgets(2));
        expect(
          find.byKey(const Key('history_load_more_error_text')),
          findsOneWidget,
        );
        expect(find.text('Timeout loading page 2'), findsOneWidget);

        // Tap retry
        final retryFinder = find.byKey(
          const Key('history_load_more_retry_button'),
        );
        expect(retryFinder, findsOneWidget);
        await tester.tap(retryFinder);
        await tester.pump();

        expect(
          mockHistoryBloc.recordedEvents,
          contains(const HistoryLoadMoreRequested()),
        );
      },
    );

    testWidgets(
      'renders cleanly on narrow mobile width without overflow errors',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          HistoryLoaded(
            runs: [tRun1, tRun2],
            pagination: tPagination,
          ),
        );

        await tester.pumpWidget(
          buildTestWidget(
            bloc: mockHistoryBloc,
            size: const Size(320, 600), // Narrow mobile
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HistoryListItem), findsNWidgets(2));
      },
    );

    testWidgets(
      'renders cleanly on wide desktop width without overflow errors',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          HistoryLoaded(
            runs: [tRun1, tRun2],
            pagination: tPagination,
          ),
        );

        await tester.pumpWidget(
          buildTestWidget(
            bloc: mockHistoryBloc,
            size: const Size(1400, 900), // Desktop / Tablet
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HistoryListItem), findsNWidgets(2));
      },
    );

    testWidgets(
      'auto-dispatches HistoryLoadRequested when mounted with HistoryInitial state',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc();

        await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
        await tester.pump();

        expect(
          mockHistoryBloc.recordedEvents,
          contains(const HistoryLoadRequested()),
        );
      },
    );

    testWidgets(
      'pull-to-refresh on empty state dispatches HistoryRefreshRequested',
      (tester) async {
        mockHistoryBloc = MockHistoryBloc(
          const HistoryLoaded(
            runs: [],
            pagination: Pagination(
              total: 0,
              limit: 20,
              offset: 0,
              hasMore: false,
            ),
          ),
        );

        await tester.pumpWidget(buildTestWidget(bloc: mockHistoryBloc));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryEmptyState), findsOneWidget);

        // Fling empty state scrollable to trigger refresh
        await tester.fling(
          find.byType(SingleChildScrollView),
          const Offset(0, 300),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          mockHistoryBloc.recordedEvents,
          contains(const HistoryRefreshRequested()),
        );
      },
    );

    testWidgets(
      'renders long method names and status labels on narrow 320px screen without overflow',
      (tester) async {
        final longRun = HistoryRun(
          id: 'long-run-1',
          method: 'numerical-calculus/runge-kutta-fourth-order-method',
          createdAt: DateTime.parse('2026-09-30T10:00:00.000Z'),
          outputPayload: const {
            'method': 'Runge-Kutta Fourth Order Extended High-Precision Method',
            'status': 'converged_successfully_within_tolerance',
            'finalAnswer': {'y': 3.141592653589793},
          },
        );

        mockHistoryBloc = MockHistoryBloc(
          HistoryLoaded(
            runs: [longRun],
            pagination: const Pagination(
              total: 1,
              limit: 20,
              offset: 0,
              hasMore: false,
            ),
          ),
        );

        await tester.pumpWidget(
          buildTestWidget(
            bloc: mockHistoryBloc,
            size: const Size(320, 600),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HistoryListItem), findsOneWidget);
        expect(
          find.byKey(Key('history_item_method_${longRun.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('history_item_date_${longRun.id}')),
          findsOneWidget,
        );
      },
    );
  });
}

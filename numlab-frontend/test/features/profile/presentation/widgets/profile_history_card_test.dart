import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_theme.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/history/domain/usecases/get_history_runs_use_case.dart';
import 'package:numlab_frontend/features/profile/presentation/widgets/profile_history_card.dart';

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

void main() {
  group('ProfileHistoryCard widget tests', () {
    late MockGetHistoryRunsUseCase mockGetHistoryRunsUseCase;

    setUp(() {
      mockGetHistoryRunsUseCase = MockGetHistoryRunsUseCase();
    });

    for (final brightness in Brightness.values) {
      testWidgets('history action fits production $brightness theme at 320px', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async => const Right(
              PaginatedHistory(
                runs: [],
                pagination: Pagination(
                  total: 0,
                  limit: 1,
                  offset: 0,
                  hasMore: false,
                ),
              ),
            );
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.lightTheme
                : AppTheme.darkTheme,
            home: Scaffold(
              body: ProfileHistoryCard(
                getHistoryRunsUseCase: mockGetHistoryRunsUseCase,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const Key('profile_history_view_all_button'));
        expect(button, findsOneWidget);
        expect(find.text('Total Solves: 0'), findsOneWidget);
        expect(tester.getSize(button).width.isFinite, isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders loading spinner while history summary is fetching', (
      tester,
    ) async {
      final completer = Completer<Either<Failure, PaginatedHistory>>();
      mockGetHistoryRunsUseCase.handler = ({int limit = 20, int offset = 0}) =>
          completer.future;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHistoryCard(
              getHistoryRunsUseCase: mockGetHistoryRunsUseCase,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('profile_history_loading_indicator')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile_history_total_count')),
        findsNothing,
      );
    });

    testWidgets(
      'displays total solver runs from pagination metadata (not list length)',
      (tester) async {
        // Backend returned total: 42, but with limit: 1 returned only 1 run item
        const tPagination = Pagination(
          total: 42,
          limit: 1,
          offset: 0,
          hasMore: true,
        );

        final tRun = HistoryRun(
          id: 'sample-run-1',
          method: 'root/bisection',
          createdAt: DateTime.parse('2026-09-30T10:00:00.000Z'),
        );

        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async => Right(
              PaginatedHistory(
                runs: [tRun],
                pagination: tPagination,
              ),
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileHistoryCard(
                getHistoryRunsUseCase: mockGetHistoryRunsUseCase,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('profile_history_loading_indicator')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('profile_history_total_count')),
          findsOneWidget,
        );
        expect(find.text('Total Solves: 42'), findsOneWidget);
        expect(
          find.text('Persisted calculations across all categories'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('profile_history_view_all_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'displays 0 and empty subtitle when total solver runs is zero',
      (
        tester,
      ) async {
        const tPagination = Pagination(
          total: 0,
          limit: 1,
          offset: 0,
          hasMore: false,
        );

        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async => const Right(
              PaginatedHistory(
                runs: [],
                pagination: tPagination,
              ),
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileHistoryCard(
                getHistoryRunsUseCase: mockGetHistoryRunsUseCase,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total Solves: 0'), findsOneWidget);
        expect(find.text('No calculations performed yet'), findsOneWidget);
        expect(
          find.byKey(const Key('profile_history_view_all_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders error message and retry button on failure without crashing Profile',
      (tester) async {
        var callCount = 0;
        mockGetHistoryRunsUseCase
            .handler = ({int limit = 20, int offset = 0}) async {
          callCount++;
          if (callCount == 1) {
            return const Left(
              ServerFailure(message: 'Failed to retrieve calculation metrics'),
            );
          }
          return const Right(
            PaginatedHistory(
              runs: [],
              pagination: Pagination(
                total: 5,
                limit: 1,
                offset: 0,
                hasMore: true,
              ),
            ),
          );
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileHistoryCard(
                getHistoryRunsUseCase: mockGetHistoryRunsUseCase,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('profile_history_error_text')),
          findsOneWidget,
        );
        expect(
          find.text('Failed to retrieve calculation metrics'),
          findsOneWidget,
        );
        final retryButtonFinder = find.byKey(
          const Key('profile_history_retry_button'),
        );
        expect(retryButtonFinder, findsOneWidget);

        // Tap retry button
        await tester.tap(retryButtonFinder);
        await tester.pumpAndSettle();

        expect(find.text('Total Solves: 5'), findsOneWidget);
        expect(callCount, 2);
      },
    );

    testWidgets('tapping View All button navigates to /history', (
      tester,
    ) async {
      var navigated = false;
      const tPagination = Pagination(
        total: 10,
        limit: 1,
        offset: 0,
        hasMore: true,
      );

      mockGetHistoryRunsUseCase.handler =
          ({int limit = 20, int offset = 0}) async => const Right(
            PaginatedHistory(
              runs: [],
              pagination: tPagination,
            ),
          );

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => Scaffold(
              body: ProfileHistoryCard(
                getHistoryRunsUseCase: mockGetHistoryRunsUseCase,
                onViewHistory: () {
                  navigated = true;
                  context.go(AppRoutes.history);
                },
              ),
            ),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const Scaffold(
              key: Key('mock_history_screen'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final viewAllFinder = find.byKey(
        const Key('profile_history_view_all_button'),
      );
      expect(viewAllFinder, findsOneWidget);

      await tester.tap(viewAllFinder);
      await tester.pumpAndSettle();

      expect(navigated, isTrue);
      expect(find.byKey(const Key('mock_history_screen')), findsOneWidget);
    });
  });
}

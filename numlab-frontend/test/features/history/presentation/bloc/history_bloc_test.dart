import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/history/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/bloc.dart';

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

void main() {
  group('HistoryBloc', () {
    late MockGetHistoryRunsUseCase mockGetHistoryRunsUseCase;
    late MockGetHistoryRunByIdUseCase mockGetHistoryRunByIdUseCase;
    late HistoryBloc historyBloc;

    final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');

    final tRun1 = HistoryRun(
      id: 'run-1',
      method: 'root/bisection',
      createdAt: timestamp,
      inputPayload: const {'equation': 'x^2 - 4'},
      outputPayload: const {
        'finalAnswer': {'root': 2.0},
      },
    );

    final tRun2 = HistoryRun(
      id: 'run-2',
      method: 'root/secant',
      createdAt: timestamp,
      inputPayload: const {'equation': 'x^2 - 4'},
      outputPayload: const {
        'finalAnswer': {'root': 2.0},
      },
    );

    final tRun3 = HistoryRun(
      id: 'run-3',
      method: 'linear/gauss-seidel',
      createdAt: timestamp,
    );

    const tPaginationPage1 = Pagination(
      total: 3,
      limit: 2,
      offset: 0,
      hasMore: true,
    );

    const tPaginationPage2 = Pagination(
      total: 3,
      limit: 2,
      offset: 2,
      hasMore: false,
    );

    final tPaginatedHistoryPage1 = PaginatedHistory(
      runs: [tRun1, tRun2],
      pagination: tPaginationPage1,
    );

    final tPaginatedHistoryPage2 = PaginatedHistory(
      runs: [tRun3],
      pagination: tPaginationPage2,
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

    test('initial state is HistoryInitial', () {
      expect(historyBloc.state, const HistoryInitial());
      expect(historyBloc.state.currentRuns, isEmpty);
      expect(historyBloc.state.currentPagination, isNull);
    });

    group('HistoryLoadRequested', () {
      test(
        'emits [HistoryLoading, HistoryLoaded] on successful initial fetch',
        () async {
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async {
                expect(limit, 20);
                expect(offset, 0);
                return Right(tPaginatedHistoryPage1);
              };

          final expectation = expectLater(
            historyBloc.stream,
            emitsInOrder(<HistoryState>[
              const HistoryLoading(),
              HistoryLoaded(
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
            ]),
          );

          historyBloc.add(const HistoryLoadRequested());
          await expectation;

          expect(historyBloc.state.currentRuns, [tRun1, tRun2]);
          expect(historyBloc.state.currentPagination, tPaginationPage1);
        },
      );

      test('forwards custom limit and offset parameters to use case', () async {
        int? capturedLimit;
        int? capturedOffset;

        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async {
              capturedLimit = limit;
              capturedOffset = offset;
              return Right(tPaginatedHistoryPage1);
            };

        final expectation = expectLater(
          historyBloc.stream,
          emitsInOrder(<HistoryState>[
            const HistoryLoading(),
            HistoryLoaded(
              runs: [tRun1, tRun2],
              pagination: tPaginationPage1,
            ),
          ]),
        );

        historyBloc.add(const HistoryLoadRequested(limit: 10, offset: 5));
        await expectation;

        expect(capturedLimit, 10);
        expect(capturedOffset, 5);
      });

      test(
        'emits [HistoryLoading, HistoryError] when use case returns failure',
        () async {
          const failure = ServerFailure(
            message: 'Failed to load history',
            statusCode: 500,
          );

          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async => const Left(failure);

          final expectation = expectLater(
            historyBloc.stream,
            emitsInOrder(<HistoryState>[
              const HistoryLoading(),
              const HistoryError(failure: failure),
            ]),
          );

          historyBloc.add(const HistoryLoadRequested());
          await expectation;

          expect(
            (historyBloc.state as HistoryError).message,
            'Failed to load history',
          );
          expect(historyBloc.state.currentRuns, isEmpty);
        },
      );
    });

    group('HistoryRefreshRequested', () {
      test(
        'refreshes history from offset 0 and replaces existing runs',
        () async {
          // First load page 1
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async =>
                  Right(tPaginatedHistoryPage1);

          historyBloc.add(const HistoryLoadRequested());
          await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

          // Now setup refresh handler returning fresh dataset
          final tRefreshedRun = HistoryRun(
            id: 'run-fresh-1',
            method: 'ode/euler',
            createdAt: timestamp,
          );
          const tRefreshedPagination = Pagination(
            total: 1,
            limit: 2,
            offset: 0,
            hasMore: false,
          );
          final tRefreshedHistory = PaginatedHistory(
            runs: [tRefreshedRun],
            pagination: tRefreshedPagination,
          );

          int? refreshOffset;
          int? refreshLimit;
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async {
                refreshLimit = limit;
                refreshOffset = offset;
                return Right(tRefreshedHistory);
              };

          final expectation = expectLater(
            historyBloc.stream,
            emitsInOrder(<HistoryState>[
              HistoryRefreshing(
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
              HistoryLoaded(
                runs: [tRefreshedRun],
                pagination: tRefreshedPagination,
              ),
            ]),
          );

          historyBloc.add(const HistoryRefreshRequested());
          await expectation;

          expect(refreshOffset, 0);
          expect(refreshLimit, 2); // preserved page limit
          expect(historyBloc.state.currentRuns, [tRefreshedRun]);
        },
      );

      test(
        'emits HistoryLoading when refreshing from initial empty state',
        () async {
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async =>
                  Right(tPaginatedHistoryPage1);

          final expectation = expectLater(
            historyBloc.stream,
            emitsInOrder(<HistoryState>[
              const HistoryLoading(),
              HistoryLoaded(
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
            ]),
          );

          historyBloc.add(const HistoryRefreshRequested());
          await expectation;
        },
      );

      test(
        'preserves existing runs in HistoryError when refresh fails',
        () async {
          // First load page 1
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async =>
                  Right(tPaginatedHistoryPage1);

          historyBloc.add(const HistoryLoadRequested());
          await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

          // Refresh fails
          const networkFailure = NetworkFailure(message: 'Connection dropped');
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async =>
                  const Left(networkFailure);

          final expectation = expectLater(
            historyBloc.stream,
            emitsInOrder(<HistoryState>[
              HistoryRefreshing(
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
              HistoryError(
                failure: networkFailure,
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
            ]),
          );

          historyBloc.add(const HistoryRefreshRequested());
          await expectation;

          expect(historyBloc.state.currentRuns, [tRun1, tRun2]);
          expect(historyBloc.state.currentPagination, tPaginationPage1);
        },
      );
    });

    group('HistoryLoadMoreRequested', () {
      test(
        'calculates next offset (offset + limit) and appends newly loaded runs',
        () async {
          // First load page 1
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async =>
                  Right(tPaginatedHistoryPage1);

          historyBloc.add(const HistoryLoadRequested());
          await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

          // Load more
          int? capturedOffset;
          int? capturedLimit;
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async {
                capturedOffset = offset;
                capturedLimit = limit;
                return Right(tPaginatedHistoryPage2);
              };

          final expectation = expectLater(
            historyBloc.stream,
            emitsInOrder(<HistoryState>[
              HistoryLoadingMore(
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
              HistoryLoaded(
                runs: [tRun1, tRun2, tRun3],
                pagination: tPaginationPage2,
              ),
            ]),
          );

          historyBloc.add(const HistoryLoadMoreRequested());
          await expectation;

          // Next offset = 0 + 2 = 2
          expect(capturedOffset, 2);
          expect(capturedLimit, 2);
          expect(historyBloc.state.currentRuns.length, 3);
          expect(historyBloc.state.currentPagination?.hasMore, false);
        },
      );

      test(
        'does not append duplicate runs if same ID appears across pages',
        () async {
          // First load page 1
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async =>
                  Right(tPaginatedHistoryPage1);

          historyBloc.add(const HistoryLoadRequested());
          await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

          // Server returns page 2 containing duplicate of run-2 and new run-3
          final duplicatePage2 = PaginatedHistory(
            runs: [tRun2, tRun3],
            pagination: tPaginationPage2,
          );
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async => Right(duplicatePage2);

          final expectation = expectLater(
            historyBloc.stream,
            emitsInOrder(<HistoryState>[
              HistoryLoadingMore(
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
              HistoryLoaded(
                runs: [tRun1, tRun2, tRun3],
                pagination: tPaginationPage2,
              ),
            ]),
          );

          historyBloc.add(const HistoryLoadMoreRequested());
          await expectation;

          // Verified: only 3 unique runs, run-2 was not duplicated
          expect(historyBloc.state.currentRuns.length, 3);
        },
      );

      test('does nothing when hasMore is false', () async {
        // Load page 2 (which has hasMore: false)
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async =>
                Right(tPaginatedHistoryPage2);

        historyBloc.add(const HistoryLoadRequested());
        await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

        var useCaseCalled = false;
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async {
              useCaseCalled = true;
              return Right(tPaginatedHistoryPage2);
            };

        historyBloc.add(const HistoryLoadMoreRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(useCaseCalled, isFalse);
        expect(historyBloc.state, isA<HistoryLoaded>());
      });

      test(
        'does nothing when no pagination metadata has been loaded yet',
        () async {
          var useCaseCalled = false;
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async {
                useCaseCalled = true;
                return Right(tPaginatedHistoryPage1);
              };

          historyBloc.add(const HistoryLoadMoreRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(useCaseCalled, isFalse);
          expect(historyBloc.state, const HistoryInitial());
        },
      );

      test('preserves existing runs when load more fails', () async {
        // First load page 1
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async =>
                Right(tPaginatedHistoryPage1);

        historyBloc.add(const HistoryLoadRequested());
        await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

        const serverError = ServerFailure(
          message: 'Server error on page 2',
          statusCode: 500,
        );
        mockGetHistoryRunsUseCase.handler =
            ({int limit = 20, int offset = 0}) async => const Left(serverError);

        final expectation = expectLater(
          historyBloc.stream,
          emitsInOrder(<HistoryState>[
            HistoryLoadingMore(
              runs: [tRun1, tRun2],
              pagination: tPaginationPage1,
            ),
            HistoryError(
              failure: serverError,
              runs: [tRun1, tRun2],
              pagination: tPaginationPage1,
            ),
          ]),
        );

        historyBloc.add(const HistoryLoadMoreRequested());
        await expectation;

        expect(historyBloc.state.currentRuns, [tRun1, tRun2]);
        expect(historyBloc.state.currentPagination, tPaginationPage1);
      });
    });

    group('HistoryRunRequested (Detail Loading)', () {
      final tDetailedRun = HistoryRun(
        id: 'run-1',
        method: 'root/bisection',
        createdAt: timestamp,
        inputPayload: const {'equation': 'x^2 - 4'},
        outputPayload: const {
          'finalAnswer': {'root': 2.0},
        },
        aiExplanations: [
          HistoryExplanation(
            id: 'exp-1',
            solverRunId: 'run-1',
            responseText: 'Detailed step-by-step AI explanation.',
            createdAt: timestamp,
          ),
        ],
      );

      test(
        'emits [HistoryDetailLoading, HistoryDetailLoaded] on success',
        () async {
          // Pre-load history list
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async =>
                  Right(tPaginatedHistoryPage1);
          historyBloc.add(const HistoryLoadRequested());
          await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

          mockGetHistoryRunByIdUseCase.handler = (runId) async {
            expect(runId, 'run-1');
            return Right(tDetailedRun);
          };

          final expectation = expectLater(
            historyBloc.stream,
            emitsInOrder(<HistoryState>[
              HistoryDetailLoading(
                runId: 'run-1',
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
              HistoryDetailLoaded(
                run: tDetailedRun,
                runs: [tDetailedRun, tRun2], // updated in list
                pagination: tPaginationPage1,
              ),
            ]),
          );

          historyBloc.add(const HistoryRunRequested('run-1'));
          await expectation;

          final detailState = historyBloc.state as HistoryDetailLoaded;
          expect(detailState.run.aiExplanations.length, 1);
          expect(detailState.runs.first.aiExplanations.length, 1);
        },
      );

      test(
        'preserves existing runs in HistoryError when detail fetch fails',
        () async {
          // Pre-load history list
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async =>
                  Right(tPaginatedHistoryPage1);
          historyBloc.add(const HistoryLoadRequested());
          await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

          const notFoundFailure = ServerFailure(
            message: 'Run not found',
            statusCode: 404,
            code: 'NOT_FOUND',
          );

          mockGetHistoryRunByIdUseCase.handler = (runId) async =>
              const Left(notFoundFailure);

          final expectation = expectLater(
            historyBloc.stream,
            emitsInOrder(<HistoryState>[
              HistoryDetailLoading(
                runId: 'run-missing',
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
              HistoryError(
                failure: notFoundFailure,
                runs: [tRun1, tRun2],
                pagination: tPaginationPage1,
              ),
            ]),
          );

          historyBloc.add(const HistoryRunRequested('run-missing'));
          await expectation;

          expect(historyBloc.state.currentRuns, [tRun1, tRun2]);
        },
      );
    });

    group('Duplicate Request Prevention & Concurrency Hardening', () {
      test(
        'HistoryLoadRequested ignores duplicate request when already loading',
        () async {
          var callCount = 0;
          final completer = Completer<Either<Failure, PaginatedHistory>>();

          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) {
                callCount++;
                return completer.future;
              };

          // First call starts loading
          historyBloc.add(const HistoryLoadRequested());
          await pumpEventQueue();

          expect(historyBloc.state, isA<HistoryLoading>());
          expect(callCount, 1);

          // Second call while still loading should be ignored
          historyBloc.add(const HistoryLoadRequested());
          await pumpEventQueue();

          expect(callCount, 1);

          completer.complete(
            Right<Failure, PaginatedHistory>(tPaginatedHistoryPage1),
          );
          await pumpEventQueue();
          expect(historyBloc.state, isA<HistoryLoaded>());
        },
      );

      test(
        'HistoryRunRequested ignores duplicate request when already loading same runId',
        () async {
          var callCount = 0;
          final completer = Completer<Either<Failure, HistoryRun>>();

          mockGetHistoryRunByIdUseCase.handler = (runId) {
            callCount++;
            return completer.future;
          };

          historyBloc.add(const HistoryRunRequested('run-1'));
          await pumpEventQueue();

          expect(historyBloc.state, isA<HistoryDetailLoading>());
          expect(callCount, 1);

          // Same runId should be ignored
          historyBloc.add(const HistoryRunRequested('run-1'));
          await pumpEventQueue();

          expect(callCount, 1);

          completer.complete(Right<Failure, HistoryRun>(tRun1));
          await pumpEventQueue();
          expect(historyBloc.state, isA<HistoryDetailLoaded>());
        },
      );

      test('HistoryRunRequested ignores empty or whitespace runId', () async {
        var callCount = 0;
        mockGetHistoryRunByIdUseCase.handler = (runId) async {
          callCount++;
          return Right<Failure, HistoryRun>(tRun1);
        };

        historyBloc
          ..add(const HistoryRunRequested(''))
          ..add(const HistoryRunRequested('   '));
        await pumpEventQueue();

        expect(callCount, 0);
        expect(historyBloc.state, isA<HistoryInitial>());
      });

      test(
        'HistoryRefreshRequested ignores duplicate request while already refreshing',
        () async {
          var callCount = 0;
          final completer = Completer<Either<Failure, PaginatedHistory>>();

          // Preload history
          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) async =>
                  Right<Failure, PaginatedHistory>(tPaginatedHistoryPage1);
          historyBloc.add(const HistoryLoadRequested());
          await historyBloc.stream.firstWhere((s) => s is HistoryLoaded);

          mockGetHistoryRunsUseCase.handler =
              ({int limit = 20, int offset = 0}) {
                callCount++;
                return completer.future;
              };

          historyBloc.add(const HistoryRefreshRequested());
          await pumpEventQueue();

          expect(historyBloc.state, isA<HistoryRefreshing>());
          expect(callCount, 1);

          // Second refresh call ignored
          historyBloc.add(const HistoryRefreshRequested());
          await pumpEventQueue();

          expect(callCount, 1);

          completer.complete(
            Right<Failure, PaginatedHistory>(tPaginatedHistoryPage1),
          );
          await pumpEventQueue();
          expect(historyBloc.state, isA<HistoryLoaded>());
        },
      );
    });

    group('State & Event Equality', () {
      test('HistoryEvent subclasses support value equality', () {
        expect(
          const HistoryLoadRequested(),
          equals(const HistoryLoadRequested()),
        );
        expect(
          const HistoryLoadRequested(limit: 10, offset: 5),
          equals(const HistoryLoadRequested(limit: 10, offset: 5)),
        );
        expect(
          const HistoryRefreshRequested(),
          equals(const HistoryRefreshRequested()),
        );
        expect(
          const HistoryLoadMoreRequested(),
          equals(const HistoryLoadMoreRequested()),
        );
        expect(
          const HistoryRunRequested('run-1'),
          equals(const HistoryRunRequested('run-1')),
        );
        expect(
          const HistoryRunRequested('run-1'),
          isNot(equals(const HistoryRunRequested('run-2'))),
        );
      });

      test('HistoryState subclasses support value equality', () {
        expect(const HistoryInitial(), equals(const HistoryInitial()));
        expect(const HistoryLoading(), equals(const HistoryLoading()));

        final stateLoaded1 = HistoryLoaded(
          runs: [tRun1],
          pagination: tPaginationPage1,
        );
        final stateLoaded2 = HistoryLoaded(
          runs: [tRun1],
          pagination: tPaginationPage1,
        );
        expect(stateLoaded1, equals(stateLoaded2));

        final stateLoadingMore1 = HistoryLoadingMore(
          runs: [tRun1],
          pagination: tPaginationPage1,
        );
        final stateLoadingMore2 = HistoryLoadingMore(
          runs: [tRun1],
          pagination: tPaginationPage1,
        );
        expect(stateLoadingMore1, equals(stateLoadingMore2));

        final stateRefreshing1 = HistoryRefreshing(
          runs: [tRun1],
          pagination: tPaginationPage1,
        );
        final stateRefreshing2 = HistoryRefreshing(
          runs: [tRun1],
          pagination: tPaginationPage1,
        );
        expect(stateRefreshing1, equals(stateRefreshing2));

        final stateDetail1 = HistoryDetailLoaded(
          run: tRun1,
          runs: [tRun1],
          pagination: tPaginationPage1,
        );
        final stateDetail2 = HistoryDetailLoaded(
          run: tRun1,
          runs: [tRun1],
          pagination: tPaginationPage1,
        );
        expect(stateDetail1, equals(stateDetail2));
      });
    });
  });
}

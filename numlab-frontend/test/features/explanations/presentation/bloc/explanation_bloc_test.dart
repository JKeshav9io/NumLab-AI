import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/entities.dart';
import 'package:numlab_frontend/features/explanations/domain/usecases/explain_use_case.dart';
import 'package:numlab_frontend/features/explanations/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

class MockExplainUseCase extends Fake implements ExplainUseCase {
  Future<Either<Failure, AiExplanationResult>> Function({
    required SolverResult solverResult,
    String? focus,
    bool? includeGraphSummary,
  })?
  handler;

  @override
  Future<Either<Failure, AiExplanationResult>> call({
    required SolverResult solverResult,
    String? focus,
    bool? includeGraphSummary,
  }) async => handler!(
    solverResult: solverResult,
    focus: focus,
    includeGraphSummary: includeGraphSummary,
  );
}

void main() {
  group('ExplanationBloc', () {
    late MockExplainUseCase mockExplainUseCase;
    late ExplanationBloc explanationBloc;

    const testSolverResult = SolverResult(
      method: 'Bisection Method',
      status: 'converged',
      input: {'equation': 'x^2 - 4'},
      iterations: [
        {'iteration': 1, 'c': 1.5, 'fC': -1.75},
        {'iteration': 2, 'c': 2.0, 'fC': 0.0},
      ],
      finalAnswer: {'root': 2.0, 'converged': true},
      executionTimeMs: 5,
    );

    const testExplanation1 = AiExplanationResult(
      explanation: 'The Bisection method converged to root 2.0.',
      model: 'gpt-4o-mini',
      method: 'Bisection Method',
      status: 'converged',
      totalTokens: 95,
      requestId: 'req-1',
    );

    const testExplanation2 = AiExplanationResult(
      explanation: 'Summary: Root 2.0 found in 2 iterations.',
      focus: 'summary',
      model: 'gpt-4o-mini',
      cached: true,
      method: 'Bisection Method',
      status: 'converged',
      totalTokens: 0,
      requestId: 'req-2',
    );

    setUp(() {
      mockExplainUseCase = MockExplainUseCase();
      explanationBloc = ExplanationBloc(explainUseCase: mockExplainUseCase);
    });

    tearDown(() async {
      await explanationBloc.close();
    });

    test(
      'initial state is ExplanationInitial with null currentExplanation',
      () {
        expect(explanationBloc.state, const ExplanationInitial());
        expect(explanationBloc.state.currentExplanation, isNull);
      },
    );

    test(
      'slow notification preserves loading data and never requests again',
      () async {
        final pending = Completer<Either<Failure, AiExplanationResult>>();
        var calls = 0;
        mockExplainUseCase.handler =
            ({required solverResult, focus, includeGraphSummary}) {
              calls++;
              return pending.future;
            };
        explanationBloc.add(const ExplanationPreloaded(testExplanation1));
        await pumpEventQueue();
        explanationBloc.add(
          const ExplanationRequested(solverResult: testSolverResult),
        );
        await pumpEventQueue();
        // Preload invalidates version 0; this request owns version 2.
        explanationBloc.add(const ExplanationWaitElapsed(2));
        await pumpEventQueue();
        expect(
          explanationBloc.state,
          const ExplanationLoading(
            previousExplanation: testExplanation1,
            isSlow: true,
          ),
        );
        explanationBloc.add(
          const ExplanationRequested(solverResult: testSolverResult),
        );
        await pumpEventQueue();
        expect(calls, 1);
        pending.complete(const Right(testExplanation2));
        await pumpEventQueue();
        expect(
          explanationBloc.state,
          const ExplanationSuccess(explanation: testExplanation2),
        );
        explanationBloc.add(const ExplanationWaitElapsed(2));
        await pumpEventQueue();
        expect(
          explanationBloc.state,
          const ExplanationSuccess(explanation: testExplanation2),
        );
      },
    );

    test(
      'ignores a superseded slow notification during the next request',
      () async {
        final old = Completer<Either<Failure, AiExplanationResult>>();
        final current = Completer<Either<Failure, AiExplanationResult>>();
        var calls = 0;
        mockExplainUseCase.handler =
            ({required solverResult, focus, includeGraphSummary}) =>
                ++calls == 1 ? old.future : current.future;
        explanationBloc.add(
          const ExplanationRequested(solverResult: testSolverResult),
        );
        await pumpEventQueue();
        explanationBloc.add(const ExplanationReset());
        await pumpEventQueue();
        explanationBloc.add(
          const ExplanationRequested(solverResult: testSolverResult),
        );
        await pumpEventQueue();
        explanationBloc.add(const ExplanationWaitElapsed(1));
        await pumpEventQueue();
        expect(explanationBloc.state, const ExplanationLoading());
        old.complete(const Right(testExplanation1));
        await pumpEventQueue();
        expect(explanationBloc.state, const ExplanationLoading());
        current.complete(const Right(testExplanation2));
        await pumpEventQueue();
        expect(calls, 2);
        expect(
          explanationBloc.state,
          const ExplanationSuccess(explanation: testExplanation2),
        );
      },
    );

    test('timeout is recoverable and retry does not overlap', () async {
      const timeout = NetworkFailure(
        message: 'The request timed out. Please try again.',
        code: 'REQUEST_TIMEOUT',
      );
      final retry = Completer<Either<Failure, AiExplanationResult>>();
      var calls = 0;
      mockExplainUseCase.handler =
          ({required solverResult, focus, includeGraphSummary}) async =>
              ++calls == 1 ? const Left(timeout) : retry.future;
      explanationBloc.add(
        const ExplanationRequested(solverResult: testSolverResult),
      );
      await pumpEventQueue();
      final failure = explanationBloc.state as ExplanationFailure;
      expect(failure.isTimeout, isTrue);
      expect(failure.isNetwork, isTrue);
      expect(failure.isServer, isFalse);
      expect(calls, 1);
      explanationBloc
        ..add(const ExplanationRequested(solverResult: testSolverResult))
        ..add(const ExplanationRequested(solverResult: testSolverResult));
      await pumpEventQueue();
      expect(explanationBloc.state, const ExplanationLoading());
      expect(calls, 2);
      retry.complete(const Right(testExplanation1));
      await pumpEventQueue();
      expect(
        explanationBloc.state,
        const ExplanationSuccess(explanation: testExplanation1),
      );
    });

    group('ExplanationRequested - Success Flow', () {
      test('close cancels slow timer and ignores pending completion', () async {
        final pending = Completer<Either<Failure, AiExplanationResult>>();
        mockExplainUseCase.handler =
            ({required solverResult, focus, includeGraphSummary}) =>
                pending.future;
        Timer? slowTimer;
        final bloc = runZoned(
          () => ExplanationBloc(explainUseCase: mockExplainUseCase),
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              final timer = parent.createTimer(zone, duration, callback);
              if (duration == const Duration(seconds: 5)) slowTimer = timer;
              return timer;
            },
          ),
        );
        final emitted = <ExplanationState>[];
        final subscription = bloc.stream.listen(emitted.add);
        bloc.add(const ExplanationRequested(solverResult: testSolverResult));
        await pumpEventQueue();
        expect(slowTimer, isNotNull);
        expect(slowTimer!.isActive, isTrue);
        final closing = bloc.close();
        expect(slowTimer!.isActive, isFalse);
        pending.complete(const Right(testExplanation1));
        await closing;
        expect(bloc.isClosed, isTrue);
        expect(emitted, [const ExplanationLoading()]);
        await subscription.cancel();
      });

      test(
        'emits [ExplanationLoading, ExplanationSuccess] on successful request',
        () async {
          mockExplainUseCase.handler =
              ({
                required solverResult,
                focus,
                includeGraphSummary,
              }) async => const Right(testExplanation1);

          final expectedStates = [
            const ExplanationLoading(),
            const ExplanationSuccess(explanation: testExplanation1),
          ];

          final expectation = expectLater(
            explanationBloc.stream,
            emitsInOrder(expectedStates),
          );

          explanationBloc.add(
            const ExplanationRequested(
              solverResult: testSolverResult,
              focus: 'steps',
              includeGraphSummary: true,
            ),
          );

          await expectation;
        },
      );

      test('forwards parameters to ExplainUseCase accurately', () async {
        SolverResult? capturedResult;
        String? capturedFocus;
        bool? capturedIncludeGraphSummary;

        mockExplainUseCase.handler =
            ({
              required solverResult,
              focus,
              includeGraphSummary,
            }) async {
              capturedResult = solverResult;
              capturedFocus = focus;
              capturedIncludeGraphSummary = includeGraphSummary;
              return const Right(testExplanation1);
            };

        explanationBloc.add(
          const ExplanationRequested(
            solverResult: testSolverResult,
            focus: 'warnings',
            includeGraphSummary: false,
          ),
        );

        await expectLater(
          explanationBloc.stream,
          emitsThrough(
            const ExplanationSuccess(explanation: testExplanation1),
          ),
        );

        expect(capturedResult, testSolverResult);
        expect(capturedFocus, 'warnings');
        expect(capturedIncludeGraphSummary, isFalse);
      });
    });

    group('ExplanationRequested - Failure Handling & Distinct Error Types', () {
      test(
        'emits [ExplanationLoading, ExplanationFailure] on ServerFailure',
        () async {
          const failure = ServerFailure(
            message: 'AI Service error',
            statusCode: 502,
            code: 'AI_SERVICE_ERROR',
          );

          mockExplainUseCase.handler =
              ({
                required solverResult,
                focus,
                includeGraphSummary,
              }) async => const Left(failure);

          final expectedStates = [
            const ExplanationLoading(),
            const ExplanationFailure(failure: failure),
          ];

          final expectation = expectLater(
            explanationBloc.stream,
            emitsInOrder(expectedStates),
          );

          explanationBloc.add(
            const ExplanationRequested(solverResult: testSolverResult),
          );

          await expectation;
        },
      );

      test(
        'handles RateLimitFailure with retryAfterSeconds and isRateLimit flag',
        () async {
          const failure = RateLimitFailure(
            message: 'Too many explanation calls. Please wait.',
            retryAfterSeconds: 45,
          );

          mockExplainUseCase.handler =
              ({
                required solverResult,
                focus,
                includeGraphSummary,
              }) async => const Left(failure);

          explanationBloc.add(
            const ExplanationRequested(solverResult: testSolverResult),
          );

          await expectLater(
            explanationBloc.stream,
            emitsThrough(
              isA<ExplanationFailure>().having(
                (s) => s.isRateLimit,
                'isRateLimit',
                isTrue,
              ),
            ),
          );

          final state = explanationBloc.state as ExplanationFailure;
          expect(state.retryAfterSeconds, 45);
          expect(state.message, contains('Too many explanation calls'));
          expect(state.isNetwork, isFalse);
        },
      );

      test('handles NetworkFailure with isNetwork flag', () async {
        const failure = NetworkFailure(
          message: 'Unable to reach backend server',
        );

        mockExplainUseCase.handler =
            ({
              required solverResult,
              focus,
              includeGraphSummary,
            }) async => const Left(failure);

        explanationBloc.add(
          const ExplanationRequested(solverResult: testSolverResult),
        );

        await expectLater(
          explanationBloc.stream,
          emitsThrough(
            isA<ExplanationFailure>().having(
              (s) => s.isNetwork,
              'isNetwork',
              isTrue,
            ),
          ),
        );

        final state = explanationBloc.state as ExplanationFailure;
        expect(state.isNetwork, isTrue);
        expect(state.isRateLimit, isFalse);
      });

      test('handles ValidationFailure and AuthFailure flags', () async {
        const valFailure = ValidationFailure(
          message: 'Invalid focus mode',
          fieldErrors: [FieldError(field: 'focus', message: 'Unknown focus')],
        );

        mockExplainUseCase.handler =
            ({
              required solverResult,
              focus,
              includeGraphSummary,
            }) async => const Left(valFailure);

        explanationBloc.add(
          const ExplanationRequested(solverResult: testSolverResult),
        );

        await expectLater(
          explanationBloc.stream,
          emitsThrough(
            isA<ExplanationFailure>().having(
              (s) => s.isValidation,
              'isValidation',
              isTrue,
            ),
          ),
        );

        final state = explanationBloc.state as ExplanationFailure;
        expect(state.isValidation, isTrue);
        expect(state.isServer, isFalse);
      });
    });

    group('Duplicate Request Prevention', () {
      test(
        'ignores duplicate ExplanationRequested while actively loading',
        () async {
          var callCount = 0;
          final completer = Completer<Either<Failure, AiExplanationResult>>();

          mockExplainUseCase.handler =
              ({
                required solverResult,
                focus,
                includeGraphSummary,
              }) {
                callCount++;
                return completer.future;
              };

          // First request starts loading
          explanationBloc.add(
            const ExplanationRequested(solverResult: testSolverResult),
          );

          await expectLater(
            explanationBloc.stream,
            emits(const ExplanationLoading()),
          );

          expect(explanationBloc.state, const ExplanationLoading());
          expect(callCount, 1);

          // Second and third duplicate requests dispatched while still in loading state
          explanationBloc
            ..add(
              const ExplanationRequested(
                solverResult: testSolverResult,
                focus: 'summary',
              ),
            )
            ..add(
              const ExplanationRequested(solverResult: testSolverResult),
            );

          // Allow microtasks to settle
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Call count MUST remain 1
          expect(callCount, 1);

          // Complete the inflight operation
          completer.complete(const Right(testExplanation1));

          await expectLater(
            explanationBloc.stream,
            emits(const ExplanationSuccess(explanation: testExplanation1)),
          );

          expect(callCount, 1);
        },
      );
    });

    group('Preserving Existing Explanation', () {
      test(
        'preserves previous explanation when loading and on subsequent failure',
        () async {
          // 1. Initial success
          mockExplainUseCase.handler =
              ({
                required solverResult,
                focus,
                includeGraphSummary,
              }) async => const Right(testExplanation1);

          explanationBloc.add(
            const ExplanationRequested(solverResult: testSolverResult),
          );

          await expectLater(
            explanationBloc.stream,
            emitsThrough(
              const ExplanationSuccess(explanation: testExplanation1),
            ),
          );

          expect(
            explanationBloc.state.currentExplanation,
            testExplanation1,
          );

          // 2. User changes focus mode; subsequent request fails with RateLimitFailure
          const rateLimitFailure = RateLimitFailure(
            message: 'Rate limit exceeded',
            retryAfterSeconds: 30,
          );

          mockExplainUseCase.handler =
              ({
                required solverResult,
                focus,
                includeGraphSummary,
              }) async => const Left(rateLimitFailure);

          final expectedStates = [
            const ExplanationLoading(previousExplanation: testExplanation1),
            const ExplanationFailure(
              failure: rateLimitFailure,
              previousExplanation: testExplanation1,
            ),
          ];

          final expectation = expectLater(
            explanationBloc.stream,
            emitsInOrder(expectedStates),
          );

          explanationBloc.add(
            const ExplanationRequested(
              solverResult: testSolverResult,
              focus: 'summary',
            ),
          );

          await expectation;

          // currentExplanation remains accessible even during and after failure
          expect(
            explanationBloc.state.currentExplanation,
            testExplanation1,
          );
        },
      );

      test(
        'replaces previous explanation when subsequent request succeeds',
        () async {
          // 1. Preload initial explanation
          explanationBloc.add(const ExplanationPreloaded(testExplanation1));

          await expectLater(
            explanationBloc.stream,
            emits(const ExplanationSuccess(explanation: testExplanation1)),
          );

          // 2. Request new focus mode
          mockExplainUseCase.handler =
              ({
                required solverResult,
                focus,
                includeGraphSummary,
              }) async => const Right(testExplanation2);

          final expectedStates = [
            const ExplanationLoading(previousExplanation: testExplanation1),
            const ExplanationSuccess(explanation: testExplanation2),
          ];

          final expectation = expectLater(
            explanationBloc.stream,
            emitsInOrder(expectedStates),
          );

          explanationBloc.add(
            const ExplanationRequested(
              solverResult: testSolverResult,
              focus: 'summary',
            ),
          );

          await expectation;

          expect(
            explanationBloc.state.currentExplanation,
            testExplanation2,
          );
        },
      );
    });

    group('ExplanationReset', () {
      for (final oldRequestFails in [false, true]) {
        for (final oldRequestFinishesFirst in [false, true]) {
          test(
            'discards late ${oldRequestFails ? 'failure' : 'success'} after reset '
            'when the old request finishes ${oldRequestFinishesFirst ? 'first' : 'last'}',
            () async {
              final oldRequest =
                  Completer<Either<Failure, AiExplanationResult>>();
              final newRequest =
                  Completer<Either<Failure, AiExplanationResult>>();
              var callCount = 0;
              final oldResponse = oldRequestFails
                  ? const Left<Failure, AiExplanationResult>(
                      NetworkFailure(message: 'Old request failed'),
                    )
                  : const Right<Failure, AiExplanationResult>(testExplanation1);

              addTearDown(() {
                if (!oldRequest.isCompleted) oldRequest.complete(oldResponse);
                if (!newRequest.isCompleted) {
                  newRequest.complete(const Right(testExplanation2));
                }
              });

              mockExplainUseCase.handler =
                  ({required solverResult, focus, includeGraphSummary}) {
                    callCount++;
                    return callCount == 1
                        ? oldRequest.future
                        : newRequest.future;
                  };

              explanationBloc.add(
                const ExplanationRequested(solverResult: testSolverResult),
              );
              await expectLater(
                explanationBloc.stream,
                emits(const ExplanationLoading()),
              );

              explanationBloc.add(const ExplanationReset());
              await expectLater(
                explanationBloc.stream,
                emits(const ExplanationInitial()),
              );

              explanationBloc.add(
                const ExplanationRequested(
                  solverResult: testSolverResult,
                  focus: 'summary',
                ),
              );
              await expectLater(
                explanationBloc.stream,
                emits(const ExplanationLoading()),
              );
              expect(callCount, 2);

              if (oldRequestFinishesFirst) {
                oldRequest.complete(oldResponse);
                await pumpEventQueue();
                expect(explanationBloc.state, const ExplanationLoading());
                expect(explanationBloc.state.currentExplanation, isNull);
              }

              newRequest.complete(const Right(testExplanation2));
              await expectLater(
                explanationBloc.stream,
                emits(const ExplanationSuccess(explanation: testExplanation2)),
              );

              if (!oldRequestFinishesFirst) {
                oldRequest.complete(oldResponse);
                await pumpEventQueue();
              }
              expect(
                explanationBloc.state,
                const ExplanationSuccess(explanation: testExplanation2),
              );
            },
          );
        }
      }

      test(
        'reset remains initial when its outstanding request completes',
        () async {
          final request = Completer<Either<Failure, AiExplanationResult>>();
          mockExplainUseCase.handler =
              ({required solverResult, focus, includeGraphSummary}) =>
                  request.future;
          addTearDown(() {
            if (!request.isCompleted) {
              request.complete(const Right(testExplanation1));
            }
          });

          explanationBloc.add(
            const ExplanationRequested(solverResult: testSolverResult),
          );
          await expectLater(
            explanationBloc.stream,
            emits(const ExplanationLoading()),
          );
          explanationBloc.add(const ExplanationReset());
          await expectLater(
            explanationBloc.stream,
            emits(const ExplanationInitial()),
          );
          request.complete(const Right(testExplanation1));
          await pumpEventQueue();
          expect(explanationBloc.state, const ExplanationInitial());
        },
      );

      test('preloading invalidates an outstanding request', () async {
        final request = Completer<Either<Failure, AiExplanationResult>>();
        mockExplainUseCase.handler =
            ({required solverResult, focus, includeGraphSummary}) =>
                request.future;
        addTearDown(() {
          if (!request.isCompleted) {
            request.complete(const Right(testExplanation1));
          }
        });

        explanationBloc.add(
          const ExplanationRequested(solverResult: testSolverResult),
        );
        await expectLater(
          explanationBloc.stream,
          emits(const ExplanationLoading()),
        );
        explanationBloc.add(const ExplanationPreloaded(testExplanation2));
        await expectLater(
          explanationBloc.stream,
          emits(const ExplanationSuccess(explanation: testExplanation2)),
        );
        request.complete(const Right(testExplanation1));
        await pumpEventQueue();
        expect(
          explanationBloc.state,
          const ExplanationSuccess(explanation: testExplanation2),
        );
      });

      test(
        'resets state from ExplanationSuccess back to ExplanationInitial',
        () async {
          explanationBloc.add(const ExplanationPreloaded(testExplanation1));

          await expectLater(
            explanationBloc.stream,
            emits(const ExplanationSuccess(explanation: testExplanation1)),
          );

          explanationBloc.add(const ExplanationReset());

          await expectLater(
            explanationBloc.stream,
            emits(const ExplanationInitial()),
          );

          expect(explanationBloc.state, const ExplanationInitial());
          expect(explanationBloc.state.currentExplanation, isNull);
        },
      );
    });
  });
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/error_mapper.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/explanations/data/models/ai_explanation_result_model.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/entities.dart';
import 'package:numlab_frontend/features/explanations/domain/usecases/explain_use_case.dart';
import 'package:numlab_frontend/features/explanations/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_result_view.dart';

class MockExplainUseCase extends Fake implements ExplainUseCase {
  FutureOr<Either<Failure, AiExplanationResult>> Function({
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
  }) {
    if (handler != null) {
      final res = handler!(
        solverResult: solverResult,
        focus: focus,
        includeGraphSummary: includeGraphSummary,
      );
      if (res is Future<Either<Failure, AiExplanationResult>>) {
        return res;
      }
      return SynchronousFuture(res);
    }
    return SynchronousFuture(
      const Right(
        AiExplanationResult(
          explanation: 'Default explanation',
          model: 'test',
          method: 'test',
          status: 'converged',
          totalTokens: 10,
        ),
      ),
    );
  }
}

void main() {
  group('AiExplanationView & SolverResultView Integration Tests', () {
    late MockExplainUseCase mockExplainUseCase;
    ExplanationBloc? explanationBloc;

    const testSolverResultA = SolverResult(
      method: 'Bisection Method',
      status: 'converged',
      input: {'equation': 'x^2 - 4'},
      iterations: [
        {'iteration': 1, 'c': 1.5, 'fC': -1.75},
        {'iteration': 2, 'c': 2.0, 'fC': 0.0},
      ],
      finalAnswer: {'root': 2.0, 'converged': true},
      executionTimeMs: 4,
    );

    const testSolverResultB = SolverResult(
      method: 'Newton-Raphson',
      status: 'converged',
      input: {'equation': 'cos(x) - x'},
      iterations: [
        {'iteration': 1, 'x': 0.739},
      ],
      finalAnswer: {'root': 0.739085, 'converged': true},
      executionTimeMs: 2,
    );

    const explanationResultA = AiExplanationResult(
      explanation: 'Bisection found root 2.0 by interval halving.',
      model: 'gpt-4o-mini',
      method: 'Bisection Method',
      status: 'converged',
      totalTokens: 80,
    );

    const cachedExplanation = AiExplanationResult(
      explanation: 'Cached mathematical analysis for this result.',
      model: 'cached',
      cached: true,
      method: 'Bisection Method',
      status: 'converged',
      totalTokens: 0,
    );

    setUp(() {
      mockExplainUseCase = MockExplainUseCase();
      explanationBloc = null;
    });

    tearDown(() async {
      await explanationBloc?.close();
    });

    Widget buildTestWidget({
      required SolverResult result,
      ExplanationBloc? bloc,
    }) {
      // Create the real BLoC inside testWidgets' async zone so pumps also drain
      // its event/state streams. Keep the same instance when replacing results.
      final effectiveBloc =
          bloc ??
          (explanationBloc ??= ExplanationBloc(
            explainUseCase: mockExplainUseCase,
          ));
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SolverResultView(
                result: result,
                explanationBloc: effectiveBloc,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('1. Idle State: renders Explain with AI button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(result: testSolverResultA));

      expect(
        find.byKey(const Key('solver_ai_explanation_section')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('explain_with_ai_button')), findsOneWidget);
      expect(find.text('Explain with AI'), findsOneWidget);
      expect(find.text('AI Explanation'), findsOneWidget);
      expect(
        find.byKey(const Key('explanation_loading_indicator')),
        findsNothing,
      );
      expect(find.byKey(const Key('explanation_success_view')), findsNothing);
      expect(find.byKey(const Key('explanation_failure_view')), findsNothing);
    });

    testWidgets('cached and fresh labels require evidence and reset', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
      for (final value in <Object?>[true, false, null, 'false']) {
        final explanation = AiExplanationResultModel.fromJson({
          'explanation': 'Current explanation',
          'cached': value,
          'model': 'cached',
        }).toEntity();
        explanationBloc!.add(ExplanationPreloaded(explanation));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('explanation_cached_chip')),
          value == true ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const Key('explanation_fresh_chip')),
          value == false ? findsOneWidget : findsNothing,
        );
      }
      explanationBloc!.add(const ExplanationPreloaded(cachedExplanation));
      await tester.pumpAndSettle();
      expect(find.text('Cached'), findsOneWidget);
      await tester.pumpWidget(buildTestWidget(result: testSolverResultB));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explanation_cached_chip')), findsNothing);
      expect(find.byKey(const Key('explanation_fresh_chip')), findsNothing);
      expect(find.text('Current explanation'), findsNothing);
    });

    testWidgets('cache label disappears during refresh and failure', (
      tester,
    ) async {
      final pending = Completer<Either<Failure, AiExplanationResult>>();
      addTearDown(() {
        if (!pending.isCompleted) {
          pending.complete(const Right(explanationResultA));
        }
      });
      mockExplainUseCase.handler =
          ({required solverResult, focus, includeGraphSummary}) =>
              pending.future;
      await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
      explanationBloc!.add(const ExplanationPreloaded(cachedExplanation));
      await tester.pumpAndSettle();
      expect(find.text('Cached'), findsOneWidget);
      explanationBloc!.add(
        const ExplanationRequested(solverResult: testSolverResultA),
      );
      await tester.pump();
      await tester.pump();
      expect(explanationBloc!.state, isA<ExplanationLoading>());
      expect(find.byKey(const Key('explanation_cached_chip')), findsNothing);
      pending.complete(const Left(NetworkFailure(message: 'Connection lost')));
      await tester.pumpAndSettle();
      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.byKey(const Key('explanation_cached_chip')), findsNothing);
      expect(find.byKey(const Key('explanation_fresh_chip')), findsNothing);
    });

    testWidgets('old cached response cannot replace a newer fresh response', (
      tester,
    ) async {
      final old = Completer<Either<Failure, AiExplanationResult>>();
      final current = Completer<Either<Failure, AiExplanationResult>>();
      addTearDown(() {
        if (!old.isCompleted) old.complete(const Right(cachedExplanation));
        if (!current.isCompleted) {
          current.complete(const Right(explanationResultA));
        }
      });
      mockExplainUseCase.handler =
          ({required solverResult, focus, includeGraphSummary}) =>
              solverResult == testSolverResultA ? old.future : current.future;
      await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
      await tester.tap(find.byKey(const Key('explain_with_ai_button')));
      await tester.pump();
      await tester.pumpWidget(buildTestWidget(result: testSolverResultB));
      await tester.pump();
      await tester.tap(find.byKey(const Key('explain_with_ai_button')));
      await tester.pump();
      current.complete(
        const Right(
          AiExplanationResult(
            explanation: 'Fresh explanation for B',
            cached: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh'), findsOneWidget);
      old.complete(const Right(cachedExplanation));
      await tester.pumpAndSettle();
      expect(find.text('Fresh explanation for B'), findsOneWidget);
      expect(find.byKey(const Key('explanation_cached_chip')), findsNothing);
      expect(find.text('Fresh'), findsOneWidget);
    });

    for (final seconds in <int?>[45, null]) {
      testWidgets('rate-limit cooldown $seconds and safe manual retry', (
        tester,
      ) async {
        final retry = Completer<Either<Failure, AiExplanationResult>>();
        addTearDown(() {
          if (!retry.isCompleted) {
            retry.complete(const Right(explanationResultA));
          }
        });
        tester.view.physicalSize = const Size(320, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        mockExplainUseCase.handler =
            ({required solverResult, focus, includeGraphSummary}) {
              calls++;
              return calls == 1
                  ? Left(
                      RateLimitFailure(
                        message: 'Quota exceeded.',
                        retryAfterSeconds: seconds,
                      ),
                    )
                  : retry.future;
            };
        await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pumpAndSettle();
        expect(find.text('AI explanation limit reached.'), findsOneWidget);
        expect(find.text('Quota exceeded.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            seconds == null
                ? 'Please wait before retrying. No retry time was provided.'
                : 'The server asked you to wait $seconds seconds before retrying.',
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 60));
        expect(calls, 1);
        final button = find.byKey(const Key('explanation_retry_button'));
        await tester.tap(button);
        await tester.tap(button);
        await tester.pump();
        expect(calls, 2);
        expect(
          find.byKey(const Key('explanation_rate_limit_message')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('explanation_cooldown_message')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('explanation_loading_indicator')),
          findsOneWidget,
        );
        retry.complete(const Right(explanationResultA));
        await tester.pumpAndSettle();
        expect(find.text(explanationResultA.explanation), findsOneWidget);
        expect(calls, 2);
      });
    }

    for (final failure in <Failure>[
      const NetworkFailure(
        message: 'Request timed out',
        code: 'REQUEST_TIMEOUT',
      ),
      const NetworkFailure(message: 'No network connection'),
      const ServerFailure(
        message: 'AI provider failed',
        code: 'AI_SERVICE_ERROR',
      ),
    ]) {
      testWidgets('keeps non-rate-limit error distinct: ${failure.message}', (
        tester,
      ) async {
        mockExplainUseCase.handler =
            ({required solverResult, focus, includeGraphSummary}) =>
                Left(failure);
        await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pumpAndSettle();
        expect(find.text(failure.message), findsOneWidget);
        expect(
          find.byKey(const Key('explanation_rate_limit_message')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('explanation_cooldown_message')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('explanation_retry_button')),
          findsOneWidget,
        );
      });
    }

    testWidgets('empty explanation offers a safe manual retry', (tester) async {
      var calls = 0;
      mockExplainUseCase.handler =
          ({required solverResult, focus, includeGraphSummary}) => ++calls == 1
          ? const Right(AiExplanationResult(explanation: ' \n '))
          : const Right(explanationResultA);
      await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
      await tester.tap(find.byKey(const Key('explain_with_ai_button')));
      await tester.pumpAndSettle();
      expect(find.text('No explanation text was returned.'), findsOneWidget);
      expect(find.byKey(const Key('solver_result_root')), findsOneWidget);
      await tester.tap(find.byKey(const Key('explanation_retry_button')));
      await tester.pumpAndSettle();
      expect(find.text(explanationResultA.explanation), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('shows immediate and 5-10 second feedback, then succeeds', (
      tester,
    ) async {
      final pending = Completer<Either<Failure, AiExplanationResult>>();
      var calls = 0;
      mockExplainUseCase.handler =
          ({required solverResult, focus, includeGraphSummary}) {
            calls++;
            return pending.future;
          };
      await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
      await tester.tap(find.byKey(const Key('explain_with_ai_button')));
      await tester.pump();
      expect(find.text('Generating AI explanation...'), findsOneWidget);
      expect(find.byKey(const Key('explanation_slow_message')), findsNothing);
      expect(explanationBloc!.state, const ExplanationLoading());

      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('explanation_slow_message')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byKey(const Key('explanation_slow_message')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(
        explanationBloc!.state,
        const ExplanationLoading(isSlow: true),
      );
      expect(
        find.byKey(const Key('explanation_loading_indicator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('explanation_retry_button')), findsNothing);
      await tester.tap(
        find.byKey(const Key('explain_with_ai_button_disabled')),
      );
      explanationBloc!.add(
        const ExplanationRequested(solverResult: testSolverResultA),
      );
      await tester.pump();
      expect(calls, 1);
      expect(find.byKey(const Key('solver_result_root')), findsOneWidget);
      expect(
        find.byKey(const Key('solver_result_iterations_section')),
        findsOneWidget,
      );

      pending.complete(const Right(explanationResultA));
      await tester.pumpAndSettle();
      expect(find.text(explanationResultA.explanation), findsOneWidget);
      expect(find.byKey(const Key('explanation_slow_message')), findsNothing);
      expect(
        find.byKey(const Key('explanation_loading_indicator')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 60));
      expect(calls, 1);
      expect(find.text(explanationResultA.explanation), findsOneWidget);
    });

    testWidgets('timeout shows manual retry and keeps retry single-flight', (
      tester,
    ) async {
      final pending = Completer<Either<Failure, AiExplanationResult>>();
      final retry = Completer<Either<Failure, AiExplanationResult>>();
      var calls = 0;
      mockExplainUseCase.handler =
          ({required solverResult, focus, includeGraphSummary}) =>
              ++calls == 1 ? pending.future : retry.future;
      await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
      await tester.tap(find.byKey(const Key('explain_with_ai_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 59));
      await tester.pump();
      expect(explanationBloc!.state, const ExplanationLoading(isSlow: true));
      expect(find.byKey(const Key('explanation_retry_button')), findsNothing);
      // The transport reports the timeout; UI elapsed time does not fail it.
      await tester.pump(const Duration(seconds: 1));
      pending.complete(
        Left(
          mapExceptionToFailure(
            DioException(
              requestOptions: RequestOptions(path: '/explain'),
              type: DioExceptionType.receiveTimeout,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('The request timed out. Please try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('explanation_retry_button')), findsOneWidget);
      expect(
        find.byKey(const Key('explanation_loading_indicator')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 60));
      expect(calls, 1);

      final retryButton = find.byKey(const Key('explanation_retry_button'));
      await tester.tap(retryButton);
      await tester.tap(retryButton);
      await tester.pump();
      expect(calls, 2);
      expect(explanationBloc!.state, const ExplanationLoading());
      expect(find.byKey(const Key('explanation_slow_message')), findsNothing);
      expect(find.byKey(const Key('explanation_retry_button')), findsNothing);
      retry.complete(const Right(explanationResultA));
      await tester.pumpAndSettle();
      expect(find.text(explanationResultA.explanation), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets(
      'switching results restarts slow feedback and ignores old completion',
      (
        tester,
      ) async {
        final old = Completer<Either<Failure, AiExplanationResult>>();
        final current = Completer<Either<Failure, AiExplanationResult>>();
        mockExplainUseCase.handler =
            ({required solverResult, focus, includeGraphSummary}) =>
                solverResult == testSolverResultA ? old.future : current.future;
        await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpWidget(buildTestWidget(result: testSolverResultB));
        await tester.pump();
        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(explanationBloc!.state, const ExplanationLoading());
        old.complete(const Right(explanationResultA));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        expect(explanationBloc!.state, const ExplanationLoading(isSlow: true));
        expect(find.text(explanationResultA.explanation), findsNothing);
        current.complete(
          const Left(NetworkFailure(message: 'Current request failed')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Current request failed'), findsOneWidget);
        await tester.pump(const Duration(seconds: 10));
        expect(find.byKey(const Key('explanation_slow_message')), findsNothing);
      },
    );

    for (final action in ['reset', 'preload']) {
      testWidgets('$action cancels pending slow feedback', (tester) async {
        final pending = Completer<Either<Failure, AiExplanationResult>>();
        mockExplainUseCase.handler =
            ({required solverResult, focus, includeGraphSummary}) =>
                pending.future;
        await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        switch (action) {
          case 'reset':
            explanationBloc!.add(const ExplanationReset());
          case 'preload':
            explanationBloc!.add(const ExplanationPreloaded(cachedExplanation));
        }
        await tester.pump();
        final expectedState = explanationBloc!.state;
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        expect(explanationBloc!.state, expectedState);
        expect(find.byKey(const Key('explanation_slow_message')), findsNothing);
        pending.complete(const Right(explanationResultA));
        await tester.pump();
        expect(explanationBloc!.state, expectedState);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      '2. Trigger Request: tapping button dispatches event and fetches explanation',
      (
        tester,
      ) async {
        mockExplainUseCase.handler =
            ({
              required solverResult,
              focus,
              includeGraphSummary,
            }) => const Right(explanationResultA);

        await tester.pumpWidget(buildTestWidget(result: testSolverResultA));

        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('explanation_success_view')),
          findsOneWidget,
        );
        expect(
          find.text('Bisection found root 2.0 by interval halving.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '3. Loading State: shows progress indicator and disabled button',
      (
        tester,
      ) async {
        final completer = Completer<Either<Failure, AiExplanationResult>>();

        mockExplainUseCase.handler =
            ({
              required solverResult,
              focus,
              includeGraphSummary,
            }) => completer.future;

        await tester.pumpWidget(buildTestWidget(result: testSolverResultA));

        // Tap button to start loading
        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pump(); // Pump frame after event processed

        // Loading state must be active
        expect(
          find.byKey(const Key('explanation_loading_indicator')),
          findsOneWidget,
        );
        expect(find.text('Generating AI explanation...'), findsOneWidget);
        expect(
          find.byKey(const Key('explain_with_ai_button_disabled')),
          findsOneWidget,
        );

        // Verify disabled button cannot trigger repeated requests
        await tester.tap(
          find.byKey(const Key('explain_with_ai_button_disabled')),
        );
        await tester.pump();

        // Complete operation
        completer.complete(const Right(explanationResultA));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('explanation_loading_indicator')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('explanation_success_view')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '4. Success State: renders explanation text, chips, and cached badge',
      (
        tester,
      ) async {
        mockExplainUseCase.handler =
            ({
              required solverResult,
              focus,
              includeGraphSummary,
            }) => const Right(cachedExplanation);

        await tester.pumpWidget(buildTestWidget(result: testSolverResultA));

        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('explanation_success_view')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('solver_ai_explanation_text')),
          findsOneWidget,
        );
        expect(
          find.text('Cached mathematical analysis for this result.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('explanation_cached_chip')),
          findsOneWidget,
        );
        expect(find.text('Cached'), findsOneWidget);
        expect(find.text('Focus: steps'), findsOneWidget);
        expect(find.text('Model: cached'), findsOneWidget);
      },
    );

    testWidgets('5. Failure State: displays error message and allows retry', (
      tester,
    ) async {
      var attempts = 0;

      mockExplainUseCase.handler =
          ({
            required solverResult,
            focus,
            includeGraphSummary,
          }) {
            attempts++;
            if (attempts == 1) {
              return const Left(
                RateLimitFailure(
                  message: 'Rate limit exceeded. Please wait 60s.',
                  retryAfterSeconds: 60,
                ),
              );
            }
            return const Right(explanationResultA);
          };

      await tester.pumpWidget(buildTestWidget(result: testSolverResultA));

      // Attempt 1 -> fails
      await tester.tap(find.byKey(const Key('explain_with_ai_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explanation_failure_view')), findsOneWidget);
      expect(
        find.text('Rate limit exceeded. Please wait 60s.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('explanation_retry_button')), findsOneWidget);

      // Attempt 2 (Retry) -> succeeds
      await tester.tap(find.byKey(const Key('explanation_retry_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explanation_failure_view')), findsNothing);
      expect(find.byKey(const Key('explanation_success_view')), findsOneWidget);
      expect(
        find.text('Bisection found root 2.0 by interval halving.'),
        findsOneWidget,
      );
      expect(attempts, 2);
    });

    testWidgets(
      '6. Stale Prevention: switching solver results resets explanation state',
      (
        tester,
      ) async {
        mockExplainUseCase.handler =
            ({
              required solverResult,
              focus,
              includeGraphSummary,
            }) => const Right(explanationResultA);

        // Step 1: Render Result A and fetch explanation
        await tester.pumpWidget(buildTestWidget(result: testSolverResultA));

        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.text('Bisection found root 2.0 by interval halving.'),
          findsOneWidget,
        );

        // Step 2: Switch to Result B (e.g. user submitted new calculation)
        await tester.pumpWidget(buildTestWidget(result: testSolverResultB));
        await tester.pump();
        await tester.pumpAndSettle();

        // Explanation A MUST NOT be displayed for Result B!
        expect(
          find.text('Bisection found root 2.0 by interval halving.'),
          findsNothing,
        );
        expect(find.byKey(const Key('explanation_success_view')), findsNothing);

        // Idle Explain with AI button is restored for Result B
        expect(find.byKey(const Key('explain_with_ai_button')), findsOneWidget);
        expect(find.text('Method: Newton-Raphson'), findsOneWidget);
      },
    );

    testWidgets('7. Preserves all other solver result sections intact', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(result: testSolverResultA));

      // Header, method, status, time, iterations chips
      expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
      expect(find.text('Calculation Result'), findsOneWidget);
      expect(find.text('Method: Bisection Method'), findsOneWidget);
      expect(find.byKey(const Key('solver_result_status')), findsOneWidget);
      expect(find.byKey(const Key('solver_result_time')), findsOneWidget);
      expect(find.byKey(const Key('solver_result_iterations')), findsOneWidget);

      // Root callout and iterations table
      expect(find.byKey(const Key('solver_result_root')), findsOneWidget);
      expect(
        find.byKey(const Key('solver_result_iterations_section')),
        findsOneWidget,
      );

      // AI explanation section coexists
      expect(
        find.byKey(const Key('solver_ai_explanation_section')),
        findsOneWidget,
      );
    });

    for (final oldRequestFails in [false, true]) {
      testWidgets(
        'switching results ignores a late ${oldRequestFails ? 'failure' : 'success'} '
        'while the new explanation is loading',
        (tester) async {
          final oldRequest = Completer<Either<Failure, AiExplanationResult>>();
          final newRequest = Completer<Either<Failure, AiExplanationResult>>();
          final requestedResults = <SolverResult>[];
          const explanationResultB = AiExplanationResult(
            explanation: 'Newton-Raphson found root 0.739085.',
            model: 'test',
            method: 'Newton-Raphson',
            status: 'converged',
            totalTokens: 20,
          );
          final oldResponse = oldRequestFails
              ? const Left<Failure, AiExplanationResult>(
                  NetworkFailure(message: 'Old explanation failed'),
                )
              : const Right<Failure, AiExplanationResult>(explanationResultA);
          addTearDown(() {
            if (!oldRequest.isCompleted) oldRequest.complete(oldResponse);
            if (!newRequest.isCompleted) {
              newRequest.complete(const Right(explanationResultB));
            }
          });
          mockExplainUseCase.handler =
              ({required solverResult, focus, includeGraphSummary}) {
                requestedResults.add(solverResult);
                return solverResult == testSolverResultA
                    ? oldRequest.future
                    : newRequest.future;
              };

          await tester.pumpWidget(buildTestWidget(result: testSolverResultA));
          await tester.tap(find.byKey(const Key('explain_with_ai_button')));
          await tester.pump();
          expect(
            find.byKey(const Key('explanation_loading_indicator')),
            findsOneWidget,
          );

          await tester.pumpWidget(buildTestWidget(result: testSolverResultB));
          await tester.pump();
          expect(
            find.byKey(const Key('explain_with_ai_button')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('explain_with_ai_button')));
          await tester.pump();
          expect(requestedResults, [testSolverResultA, testSolverResultB]);

          oldRequest.complete(oldResponse);
          await tester.pump();
          expect(
            find.byKey(const Key('explanation_loading_indicator')),
            findsOneWidget,
          );
          expect(find.text(explanationResultA.explanation), findsNothing);
          expect(
            find.byKey(const Key('explanation_failure_view')),
            findsNothing,
          );

          newRequest.complete(const Right(explanationResultB));
          await tester.pumpAndSettle();
          expect(find.text(explanationResultB.explanation), findsOneWidget);
          expect(find.text(explanationResultA.explanation), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'all explanation states fit a 320px result with charts and warnings',
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final request = Completer<Either<Failure, AiExplanationResult>>();
        var callCount = 0;
        mockExplainUseCase.handler =
            ({required solverResult, focus, includeGraphSummary}) {
              callCount++;
              return callCount == 1
                  ? request.future
                  : const Right(cachedExplanation);
            };
        addTearDown(() {
          if (!request.isCompleted) {
            request.complete(const Right(cachedExplanation));
          }
        });
        final result = SolverResult(
          method: testSolverResultA.method,
          status: testSolverResultA.status,
          input: testSolverResultA.input,
          finalAnswer: testSolverResultA.finalAnswer,
          iterations: testSolverResultA.iterations,
          warnings: const ['Example solver warning'],
          graphData: const [
            {'x': 1, 'y': -3},
            {'x': 2, 'y': 0},
          ],
        );
        await tester.pumpWidget(buildTestWidget(result: result));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.tap(find.byKey(const Key('explain_with_ai_button')));
        await tester.pump();
        expect(callCount, 1);
        expect(
          find.byKey(const Key('explanation_loading_indicator')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(
          find.byKey(const Key('explanation_slow_message')),
          findsOneWidget,
        );
        expect(callCount, 1);
        expect(tester.takeException(), isNull);

        request.complete(
          const Left(
            NetworkFailure(
              message: 'Unable to fetch explanation. Retry this request.',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('explanation_failure_view')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('explanation_retry_button')));
        await tester.pumpAndSettle();
        expect(callCount, 2);
        expect(find.text(cachedExplanation.explanation), findsOneWidget);
        expect(
          find.byKey(const Key('explanation_cached_chip')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('solver_chart_view')), findsOneWidget);
        expect(
          find.byKey(const Key('solver_result_iterations_section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('solver_final_answer_section')),
          findsOneWidget,
        );
        expect(find.text('• Example solver warning'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

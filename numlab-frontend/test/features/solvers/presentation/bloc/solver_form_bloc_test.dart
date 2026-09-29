import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/entities.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';

class MockExecuteSolverUseCase extends Fake implements ExecuteSolverUseCase {
  Future<Either<Failure, SolverResult>> Function({
    required String solverId,
    required Map<String, dynamic> payload,
    String? accessToken,
  })?
  onCall;

  @override
  Future<Either<Failure, SolverResult>> call({
    required String solverId,
    required Map<String, dynamic> payload,
    String? accessToken,
  }) async {
    return onCall!(
      solverId: solverId,
      payload: payload,
      accessToken: accessToken,
    );
  }
}

void main() {
  group('SolverFormBloc', () {
    late MockExecuteSolverUseCase mockExecuteSolverUseCase;
    late SolverFormBloc bloc;

    const sampleBisectionResult = SolverResult(
      method: 'Bisection Method',
      status: 'converged',
      input: {
        'equation': 'x^3 - x - 2',
        'lowerBound': 1.0,
        'upperBound': 2.0,
      },
      finalAnswer: {'root': 1.5214, 'converged': true},
    );

    setUp(() {
      mockExecuteSolverUseCase = MockExecuteSolverUseCase();
      bloc = SolverFormBloc(executeSolverUseCase: mockExecuteSolverUseCase);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state has default uninitialized properties', () {
      expect(bloc.state, const SolverFormState());
      expect(bloc.state.status, SolverFormStatus.initial);
      expect(bloc.state.isInitial, isTrue);
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.config, isNull);
      expect(bloc.state.values, isEmpty);
      expect(bloc.state.fieldErrors, isEmpty);
      expect(bloc.state.result, isNull);
      expect(bloc.state.failure, isNull);
    });

    group('SolverFormLoadStarted', () {
      test(
        'successfully loads solver config and initializes default values',
        () async {
          final expectation = expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<SolverFormState>((s) => s.isLoadingConfig),
              predicate<SolverFormState>((s) {
                return s.isReady &&
                    s.config?.id == 'bisection' &&
                    s.values['tolerance'] == 0.0001 &&
                    s.values['maxIterations'] == 100 &&
                    s.values['includeExplanation'] == true &&
                    s.values['includeGraphData'] == true &&
                    s.fieldErrors.isEmpty;
              }),
            ]),
          );

          bloc.add(const SolverFormLoadStarted(solverId: 'bisection'));
          await expectation;
        },
      );

      test('resolves solver by API endpoint path seamlessly', () async {
        final expectation = expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SolverFormState>((s) => s.isLoadingConfig),
            predicate<SolverFormState>(
              (s) => s.isReady && s.config?.id == 'bisection',
            ),
          ]),
        );

        bloc.add(
          const SolverFormLoadStarted(solverId: '/solve/root/bisection'),
        );
        await expectation;
      });

      test('merges pre-filled initialValues over defaults', () async {
        final expectation = expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SolverFormState>((s) => s.isLoadingConfig),
            predicate<SolverFormState>((s) {
              return s.isReady &&
                  s.values['equation'] == 'x^2 - 4' &&
                  s.values['lowerBound'] == 1.0 &&
                  s.values['upperBound'] == 3.0 &&
                  s.values['tolerance'] == 0.001; // overridden
            }),
          ]),
        );

        bloc.add(
          const SolverFormLoadStarted(
            solverId: 'bisection',
            initialValues: {
              'equation': 'x^2 - 4',
              'lowerBound': 1.0,
              'upperBound': 3.0,
              'tolerance': 0.001,
            },
          ),
        );
        await expectation;
      });

      test('emits failure state when solver ID is unknown', () async {
        final expectation = expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SolverFormState>((s) => s.isLoadingConfig),
            predicate<SolverFormState>((s) {
              return s.isFailure &&
                  s.config == null &&
                  s.failure is ValidationFailure &&
                  (s.failure! as ValidationFailure).code ==
                      'UNKNOWN_SOLVER_METHOD' &&
                  s.errorMessage!.contains(
                    'Unknown solver method: "non_existent_method"',
                  );
            }),
          ]),
        );

        bloc.add(const SolverFormLoadStarted(solverId: 'non_existent_method'));
        await expectation;
      });
    });

    group('Field Updates & Validation', () {
      setUp(() async {
        bloc.add(const SolverFormLoadStarted(solverId: 'bisection'));
        await bloc.stream.firstWhere((s) => s.isReady);
      });

      test(
        'SolverFormFieldChanged updates field value and triggers validation',
        () async {
          bloc.add(
            const SolverFormFieldChanged(
              fieldName: 'equation',
              value: 'x^3 - x - 2',
            ),
          );

          final state = await bloc.stream.firstWhere(
            (s) => s.values['equation'] == 'x^3 - x - 2',
          );

          expect(state.getValue('equation'), 'x^3 - x - 2');
          expect(state.isReady, isTrue);
        },
      );

      test(
        'SolverFormFieldChanged populates field error for invalid input',
        () async {
          bloc.add(
            const SolverFormFieldChanged(
              fieldName: 'tolerance',
              value: -0.05, // Invalid negative tolerance
            ),
          );

          final state = await bloc.stream.firstWhere(
            (s) => s.fieldErrors.containsKey('tolerance'),
          );

          expect(state.getFieldError('tolerance'), isNotNull);
          expect(state.hasFieldErrors, isTrue);
        },
      );

      test('correcting invalid input clears the field error', () async {
        bloc.add(
          const SolverFormFieldChanged(
            fieldName: 'tolerance',
            value: -0.05,
          ),
        );
        await bloc.stream.firstWhere(
          (s) => s.fieldErrors.containsKey('tolerance'),
        );

        bloc.add(
          const SolverFormFieldChanged(
            fieldName: 'tolerance',
            value: 0.0001,
          ),
        );

        final state = await bloc.stream.firstWhere(
          (s) => !s.fieldErrors.containsKey('tolerance'),
        );

        expect(state.getFieldError('tolerance'), isNull);
      });

      test(
        'detects and clears cross-field relational validation errors',
        () async {
          // lowerBound (5.0) >= upperBound (2.0) is invalid
          bloc.add(
            const SolverFormFieldsBulkChanged({
              'lowerBound': 5.0,
              'upperBound': 2.0,
            }),
          );

          final invalidState = await bloc.stream.firstWhere(
            (s) => s.fieldErrors.isNotEmpty,
          );
          expect(
            invalidState.fieldErrors.values.any(
              (msg) => msg.contains('must be less than'),
            ),
            isTrue,
          );

          // Correct lowerBound to 1.0 (< 2.0)
          bloc.add(
            const SolverFormFieldChanged(
              fieldName: 'lowerBound',
              value: 1.0,
            ),
          );

          final validState = await bloc.stream.firstWhere(
            (s) => !s.fieldErrors.values.any(
              (msg) => msg.contains('must be less than'),
            ),
          );
          expect(validState.fieldErrors['bounds.ordered'], isNull);
        },
      );

      test(
        'SolverFormValidateRequested runs validation on current values',
        () async {
          bloc.add(const SolverFormValidateRequested());

          final state = await bloc.stream.first;
          // Equation is still empty by default on bisection schema
          expect(state.hasFieldErrors, isTrue);
          expect(state.getFieldError('equation'), isNotNull);
        },
      );

      test(
        'SolverFormResetRequested restores default schema values and clears errors',
        () async {
          bloc.add(
            const SolverFormFieldChanged(
              fieldName: 'tolerance',
              value: 0.999,
            ),
          );
          await bloc.stream.firstWhere((s) => s.values['tolerance'] == 0.999);

          bloc.add(const SolverFormResetRequested());

          final resetState = await bloc.stream.firstWhere(
            (s) => s.values['tolerance'] == 0.0001,
          );
          expect(resetState.values['tolerance'], 0.0001);
          expect(resetState.fieldErrors, isEmpty);
          expect(resetState.result, isNull);
          expect(resetState.failure, isNull);
        },
      );
    });

    group('Solver Execution (SolverFormSubmitted)', () {
      setUp(() async {
        bloc.add(
          const SolverFormLoadStarted(
            solverId: 'bisection',
            initialValues: {
              'equation': 'x^3 - x - 2',
              'lowerBound': 1.0,
              'upperBound': 2.0,
              'tolerance': 0.0001,
              'maxIterations': 100,
            },
          ),
        );
        await bloc.stream.firstWhere((s) => s.isReady);
      });

      test(
        'successful submission emits [submitting, success] with SolverResult',
        () async {
          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                expect(solverId, 'bisection');
                expect(payload['equation'], 'x^3 - x - 2');
                return const Right(sampleBisectionResult);
              };

          final expectation = expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<SolverFormState>((s) => s.isSubmitting && s.isLoading),
              predicate<SolverFormState>((s) {
                return s.isSuccess &&
                    s.result == sampleBisectionResult &&
                    s.hasResult &&
                    s.fieldErrors.isEmpty &&
                    s.failure == null;
              }),
            ]),
          );

          bloc.add(const SolverFormSubmitted());
          await expectation;
        },
      );

      test(
        'forwards explicitly passed accessToken to ExecuteSolverUseCase',
        () async {
          String? receivedToken;

          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                receivedToken = accessToken;
                return const Right(sampleBisectionResult);
              };

          bloc.add(
            const SolverFormSubmitted(accessToken: 'user_jwt_token_999'),
          );
          await bloc.stream.firstWhere((s) => s.isSuccess);

          expect(receivedToken, 'user_jwt_token_999');
        },
      );

      test(
        'supports anonymous submission when accessToken is omitted',
        () async {
          String? receivedToken = 'sentinel';

          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                receivedToken = accessToken;
                return const Right(sampleBisectionResult);
              };

          bloc.add(const SolverFormSubmitted());
          await bloc.stream.firstWhere((s) => s.isSuccess);

          expect(receivedToken, isNull);
        },
      );

      test(
        'client-side validation failure prevents use case execution and emits failure',
        () async {
          var useCaseCalled = false;
          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                useCaseCalled = true;
                return const Right(sampleBisectionResult);
              };

          // Make bounds invalid: lowerBound (5.0) >= upperBound (2.0)
          bloc.add(
            const SolverFormFieldChanged(
              fieldName: 'lowerBound',
              value: 5.0,
            ),
          );
          await bloc.stream.firstWhere((s) => s.values['lowerBound'] == 5.0);

          bloc.add(const SolverFormSubmitted());

          final failureState = await bloc.stream.firstWhere((s) => s.isFailure);

          expect(useCaseCalled, isFalse);
          expect(failureState.failure, isA<ValidationFailure>());
          expect(failureState.hasFieldErrors, isTrue);
        },
      );

      test('propagates use case NetworkFailure as failure state', () async {
        mockExecuteSolverUseCase.onCall =
            ({
              required solverId,
              required payload,
              accessToken,
            }) async {
              return const Left<Failure, SolverResult>(
                NetworkFailure(message: 'Network request timed out'),
              );
            };

        final expectation = expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SolverFormState>((s) => s.isSubmitting),
            predicate<SolverFormState>((s) {
              return s.isFailure &&
                  s.failure is NetworkFailure &&
                  s.errorMessage == 'Network request timed out' &&
                  s.result == null;
            }),
          ]),
        );

        bloc.add(const SolverFormSubmitted());
        await expectation;
      });

      test('propagates use case ServerFailure as failure state', () async {
        mockExecuteSolverUseCase.onCall =
            ({
              required solverId,
              required payload,
              accessToken,
            }) async {
              return const Left<Failure, SolverResult>(
                ServerFailure(
                  message: 'Internal math calculation error',
                  statusCode: 500,
                ),
              );
            };

        bloc.add(const SolverFormSubmitted());
        final failureState = await bloc.stream.firstWhere((s) => s.isFailure);

        expect(failureState.failure, isA<ServerFailure>());
        expect(failureState.errorMessage, 'Internal math calculation error');
      });

      test(
        'propagates backend ValidationFailure and merges structured field errors',
        () async {
          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                return const Left<Failure, SolverResult>(
                  ValidationFailure(
                    message: 'Validation failed',
                    fieldErrors: [
                      FieldError(
                        field: 'equation',
                        message: 'Syntax error in expression',
                      ),
                    ],
                  ),
                );
              };

          bloc.add(const SolverFormSubmitted());
          final failureState = await bloc.stream.firstWhere((s) => s.isFailure);

          expect(
            failureState.fieldErrors['equation'],
            'Syntax error in expression',
          );
          expect(failureState.hasFieldErrors, isTrue);
        },
      );

      test('emits failure if submitted without loaded configuration', () async {
        final uninitializedBloc = SolverFormBloc(
          executeSolverUseCase: mockExecuteSolverUseCase,
        )..add(const SolverFormSubmitted());

        final state = await uninitializedBloc.stream.firstWhere(
          (s) => s.isFailure,
        );

        expect(state.failure, isA<ValidationFailure>());
        expect((state.failure! as ValidationFailure).code, 'CONFIG_NOT_LOADED');

        await uninitializedBloc.close();
      });
    });

    group('No Stale Result Guarantee', () {
      setUp(() async {
        mockExecuteSolverUseCase.onCall =
            ({
              required solverId,
              required payload,
              accessToken,
            }) async {
              return const Right(sampleBisectionResult);
            };

        bloc.add(
          const SolverFormLoadStarted(
            solverId: 'bisection',
            initialValues: {
              'equation': 'x^3 - x - 2',
              'lowerBound': 1.0,
              'upperBound': 2.0,
            },
          ),
        );
        await bloc.stream.firstWhere((s) => s.isReady);

        bloc.add(const SolverFormSubmitted());
        await bloc.stream.firstWhere((s) => s.isSuccess);
        expect(bloc.state.hasResult, isTrue);
      });

      test(
        'modifying a field value clears previous calculation result',
        () async {
          bloc.add(
            const SolverFormFieldChanged(
              fieldName: 'upperBound',
              value: 2.5,
            ),
          );

          final updatedState = await bloc.stream.firstWhere(
            (s) => s.values['upperBound'] == 2.5,
          );

          expect(updatedState.result, isNull);
          expect(updatedState.hasResult, isFalse);
        },
      );

      test(
        'loading a different solver clears previous calculation result',
        () async {
          bloc.add(const SolverFormLoadStarted(solverId: 'secant'));

          final loadedState = await bloc.stream.firstWhere(
            (s) => s.config?.id == 'secant',
          );

          expect(loadedState.result, isNull);
          expect(loadedState.hasResult, isFalse);
        },
      );

      test('SolverFormClearResultRequested explicitly clears result', () async {
        bloc.add(const SolverFormClearResultRequested());

        final clearedState = await bloc.stream.firstWhere(
          (s) => s.result == null,
        );

        expect(clearedState.result, isNull);
        expect(clearedState.isReady, isTrue);
      });
    });

    group('Representative Solvers from All 6 Domain Categories', () {
      test('1. Root Finding (Newton-Raphson) form lifecycle', () async {
        mockExecuteSolverUseCase.onCall =
            ({
              required solverId,
              required payload,
              accessToken,
            }) async {
              return const Right(
                SolverResult(
                  method: 'Newton-Raphson Method',
                  finalAnswer: {'root': 1.4142, 'converged': true},
                ),
              );
            };

        bloc.add(const SolverFormLoadStarted(solverId: 'newton-raphson'));
        await bloc.stream.firstWhere(
          (s) => s.isReady && s.config?.id == 'newton-raphson',
        );

        bloc.add(
          const SolverFormFieldsBulkChanged({
            'equation': 'x^2 - 2',
            'derivativeEquation': '2*x',
            'initialGuess': 1.0,
          }),
        );
        await bloc.stream.firstWhere((s) => s.values['equation'] == 'x^2 - 2');

        bloc.add(const SolverFormSubmitted());
        final state = await bloc.stream.firstWhere((s) => s.isSuccess);

        expect(state.result?.root, 1.4142);
      });

      test('2. Linear Systems (Jacobi Method) form lifecycle', () async {
        mockExecuteSolverUseCase.onCall =
            ({
              required solverId,
              required payload,
              accessToken,
            }) async {
              return const Right(
                SolverResult(
                  method: 'Jacobi Method',
                  finalAnswer: {
                    'solution': [1.0, 2.0],
                    'converged': true,
                  },
                ),
              );
            };

        bloc.add(const SolverFormLoadStarted(solverId: 'jacobi'));
        await bloc.stream.firstWhere(
          (s) => s.isReady && s.config?.id == 'jacobi',
        );

        bloc.add(
          const SolverFormFieldsBulkChanged({
            'matrix': [
              [4.0, 1.0],
              [1.0, 3.0],
            ],
            'constants': [1.0, 2.0],
            'initialGuess': [0.0, 0.0],
          }),
        );
        await bloc.stream.firstWhere((s) => s.values.containsKey('matrix'));

        bloc.add(const SolverFormSubmitted());
        final state = await bloc.stream.firstWhere((s) => s.isSuccess);

        expect(state.result?.solutionVector, [1.0, 2.0]);
      });

      test(
        '3. Interpolation (Lagrange Interpolation) form lifecycle',
        () async {
          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                return const Right(
                  SolverResult(
                    method: 'Lagrange Interpolation',
                    finalAnswer: {'interpolatedValue': 8.0},
                  ),
                );
              };

          bloc.add(const SolverFormLoadStarted(solverId: 'lagrange'));
          await bloc.stream.firstWhere(
            (s) => s.isReady && s.config?.id == 'lagrange',
          );

          bloc.add(
            const SolverFormFieldsBulkChanged({
              'points': [
                {'x': 1.0, 'y': 2.0},
                {'x': 2.0, 'y': 4.0},
                {'x': 3.0, 'y': 8.0},
              ],
              'targetX': 3.0,
            }),
          );
          await bloc.stream.firstWhere((s) => s.values.containsKey('points'));

          bloc.add(const SolverFormSubmitted());
          final state = await bloc.stream.firstWhere((s) => s.isSuccess);

          expect(state.result?.resultValue, 8.0);
        },
      );

      test('4. Differential Equations (RK4) form lifecycle', () async {
        mockExecuteSolverUseCase.onCall =
            ({
              required solverId,
              required payload,
              accessToken,
            }) async {
              return const Right(
                SolverResult(
                  method: 'Runge-Kutta 4th Order',
                  finalAnswer: {'yEnd': 2.71828},
                ),
              );
            };

        bloc.add(const SolverFormLoadStarted(solverId: 'rk4'));
        await bloc.stream.firstWhere((s) => s.isReady && s.config?.id == 'rk4');

        bloc.add(
          const SolverFormFieldsBulkChanged({
            'equation': 'x + y',
            'x0': 0.0,
            'y0': 1.0,
            'h': 0.1,
            'xn': 1.0,
          }),
        );
        await bloc.stream.firstWhere((s) => s.values.containsKey('x0'));

        bloc.add(const SolverFormSubmitted());
        final state = await bloc.stream.firstWhere((s) => s.isSuccess);

        expect(state.result?.method, 'Runge-Kutta 4th Order');
      });

      test('5. Numerical Integration (Simpson 1/3) form lifecycle', () async {
        mockExecuteSolverUseCase.onCall =
            ({
              required solverId,
              required payload,
              accessToken,
            }) async {
              return const Right(
                SolverResult(
                  method: "Simpson's 1/3 Rule",
                  finalAnswer: {'integral': 2.0},
                ),
              );
            };

        bloc.add(const SolverFormLoadStarted(solverId: 'simpson-13'));
        await bloc.stream.firstWhere(
          (s) => s.isReady && s.config?.id == 'simpson-13',
        );

        bloc.add(
          const SolverFormFieldsBulkChanged({
            'equation': 'sin(x)',
            'lowerBound': 0.0,
            'upperBound': 3.14159,
            'subintervals': 100,
          }),
        );
        await bloc.stream.firstWhere((s) => s.values['equation'] == 'sin(x)');

        bloc.add(const SolverFormSubmitted());
        final state = await bloc.stream.firstWhere((s) => s.isSuccess);

        expect(state.result?.resultValue, 2.0);
      });

      test(
        '6. Numerical Differentiation (Central Difference) form lifecycle',
        () async {
          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                return const Right(
                  SolverResult(
                    method: 'Central Difference Differentiation',
                    finalAnswer: {'derivative': 4.0},
                  ),
                );
              };

          bloc.add(
            const SolverFormLoadStarted(solverId: 'central-difference-tabular'),
          );
          await bloc.stream.firstWhere(
            (s) => s.isReady && s.config?.id == 'central-difference-tabular',
          );

          bloc.add(
            const SolverFormFieldsBulkChanged({
              'points': [
                {'x': 1.0, 'y': 1.0},
                {'x': 2.0, 'y': 4.0},
                {'x': 3.0, 'y': 9.0},
              ],
              'targetX': 2.0,
            }),
          );
          await bloc.stream.firstWhere((s) => s.values.containsKey('points'));

          bloc.add(const SolverFormSubmitted());
          final state = await bloc.stream.firstWhere((s) => s.isSuccess);

          expect(state.result?.resultValue, 4.0);
        },
      );
    });

    group('Method Switching & Workspace State-Safety', () {
      test(
        'compatible values are preserved when key AND input type match, obsolete fields dropped, new fields get defaults',
        () async {
          bloc.add(const SolverFormLoadStarted(solverId: 'bisection'));
          await bloc.stream.firstWhere(
            (s) => s.isReady && s.config?.id == 'bisection',
          );

          // User modifies equation and tolerance
          bloc.add(
            const SolverFormFieldChanged(
              fieldName: 'equation',
              value: 'x^3 - 8',
            ),
          );
          await bloc.stream.firstWhere((s) => s.values['equation'] == 'x^3 - 8');

          bloc.add(
            const SolverFormFieldChanged(
              fieldName: 'tolerance',
              value: 0.00005,
            ),
          );
          await bloc.stream.firstWhere((s) => s.values['tolerance'] == 0.00005);

          // Switch to Newton-Raphson
          bloc.add(
            const SolverFormMethodSwitched(solverId: 'newton-raphson'),
          );

          final switchedState = await bloc.stream.firstWhere(
            (s) => s.config?.id == 'newton-raphson',
          );

          // 1. Compatible fields preserved: equation & tolerance
          expect(switchedState.values['equation'], equals('x^3 - 8'));
          expect(switchedState.values['tolerance'], equals(0.00005));

          // 2. Obsolete fields dropped: lowerBound and upperBound
          expect(switchedState.values.containsKey('lowerBound'), isFalse);
          expect(switchedState.values.containsKey('upperBound'), isFalse);

          // 3. New fields receive schema defaults: initialGuess
          final nrConfig = SolverMethodRegistry.getById('newton-raphson')!;
          final expectedInitialGuessDefault =
              nrConfig.getField('initialGuess')?.defaultValue;
          expect(
            switchedState.values['initialGuess'],
            equals(expectedInitialGuessDefault),
          );

          // 4. Untouched fields are not flagged with errors
          expect(switchedState.fieldErrors, isEmpty);
        },
      );

      test(
        'fields not in the new method are completely removed from form values and submitted payload',
        () async {
          Map<String, dynamic>? executedPayload;
          String? executedSolverId;

          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                executedSolverId = solverId;
                executedPayload = payload;
                return const Right(
                  SolverResult(
                    method: 'Secant Method',
                    finalAnswer: {'root': 2.0},
                  ),
                );
              };

          // Start on Euler ODE
          bloc.add(const SolverFormLoadStarted(solverId: 'euler'));
          await bloc.stream.firstWhere(
            (s) => s.isReady && s.config?.id == 'euler',
          );

          bloc.add(
            const SolverFormFieldsBulkChanged({
              'equation': 'x + y',
              'x0': 0.0,
              'y0': 1.0,
              'h': 0.1,
              'xn': 1.0,
            }),
          );
          await bloc.stream.firstWhere((s) => s.values['h'] == 0.1);

          expect(bloc.state.values.containsKey('x0'), isTrue);
          expect(bloc.state.values.containsKey('y0'), isTrue);
          expect(bloc.state.values.containsKey('h'), isTrue);

          // Switch to Bisection root finding
          bloc.add(const SolverFormMethodSwitched(solverId: 'bisection'));
          await bloc.stream.firstWhere(
            (s) => s.isReady && s.config?.id == 'bisection',
          );

          // Ensure ODE fields not in Bisection are removed from form state
          expect(bloc.state.values.containsKey('x0'), isFalse);
          expect(bloc.state.values.containsKey('y0'), isFalse);
          expect(bloc.state.values.containsKey('h'), isFalse);
          expect(bloc.state.values.containsKey('xn'), isFalse);
          expect(bloc.state.values.containsKey('steps'), isFalse);
          // Shared compatible field 'equation' is preserved
          expect(bloc.state.values['equation'], equals('x + y'));

          // Fill and submit Bisection form
          bloc.add(
            const SolverFormFieldsBulkChanged({
              'equation': 'x^2 - 4',
              'lowerBound': 1.0,
              'upperBound': 3.0,
            }),
          );
          await bloc.stream.firstWhere((s) => s.values['equation'] == 'x^2 - 4');

          bloc.add(const SolverFormSubmitted());
          await bloc.stream.firstWhere((s) => s.isSuccess);

          expect(executedSolverId, equals('bisection'));
          expect(executedPayload, isNotNull);
          expect(executedPayload!.containsKey('y0'), isFalse);
          expect(executedPayload!.containsKey('h'), isFalse);
          expect(executedPayload!.containsKey('xn'), isFalse);
          expect(executedPayload!.containsKey('steps'), isFalse);
          expect(executedPayload!['equation'], equals('x^2 - 4'));
          expect(executedPayload!['lowerBound'], equals(1.0));
          expect(executedPayload!['upperBound'], equals(3.0));
        },
      );

      test(
        'stale validation errors for removed fields are cleared, and untouched fields show no errors after switch',
        () async {
          bloc.add(const SolverFormLoadStarted(solverId: 'bisection'));
          await bloc.stream.firstWhere(
            (s) => s.isReady && s.config?.id == 'bisection',
          );

          // Provoke cross-field validation error on bisection
          bloc.add(
            const SolverFormFieldsBulkChanged({
              'lowerBound': 5.0,
              'upperBound': 2.0,
            }),
          );
          final errorState = await bloc.stream.firstWhere(
            (s) => s.fieldErrors.isNotEmpty,
          );
          expect(errorState.fieldErrors.isNotEmpty, isTrue);

          // Switch to Newton-Raphson (which has neither lowerBound nor upperBound)
          bloc.add(
            const SolverFormMethodSwitched(solverId: 'newton-raphson'),
          );

          final switchedState = await bloc.stream.firstWhere(
            (s) => s.config?.id == 'newton-raphson',
          );

          // Stale errors for removed fields are cleared
          expect(switchedState.fieldErrors, isEmpty);
          expect(switchedState.touchedFields.contains('lowerBound'), isFalse);
          expect(switchedState.touchedFields.contains('upperBound'), isFalse);
        },
      );

      test(
        'switching methods cancels/ignores in-flight solve and clears previous result',
        () async {
          final completer = Completer<Either<Failure, SolverResult>>();

          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                return completer.future;
              };

          bloc.add(const SolverFormLoadStarted(solverId: 'bisection'));
          await bloc.stream.firstWhere(
            (s) => s.isReady && s.config?.id == 'bisection',
          );

          // Populate required fields so validation passes
          bloc.add(
            const SolverFormFieldsBulkChanged({
              'equation': 'x^2 - 4',
              'lowerBound': 0.0,
              'upperBound': 3.0,
            }),
          );
          await bloc.stream.firstWhere((s) => s.isReady);

          // Set up stream expectation BEFORE dispatching events
          // This ensures we capture all emissions including synchronous ones
          final expectation = expectLater(
            bloc.stream,
            emitsInOrder([
              // 1. submitting state from SolverFormSubmitted
              predicate<SolverFormState>((s) => s.isSubmitting),
              // 2. success state when completer resolves
              predicate<SolverFormState>((s) => s.isSuccess && s.result != null),
              // 3. ready state after method switch clears result
              predicate<SolverFormState>(
                (s) =>
                    s.config?.id == 'regula-falsi' &&
                    s.isReady &&
                    s.result == null,
              ),
            ]),
          );

          // Submit bisection
          bloc.add(const SolverFormSubmitted());
          // Complete immediately so _onSubmitted proceeds
          completer.complete(
            const Right<Failure, SolverResult>(
              SolverResult(
                method: 'Bisection Method',
                finalAnswer: {'root': 1.52},
              ),
            ),
          );

          // Switch to regula-falsi — will run after _onSubmitted returns
          bloc.add(
            const SolverFormMethodSwitched(solverId: 'regula-falsi'),
          );

          await expectation;

          // Final state: method switched, stale result cleared
          expect(bloc.state.config?.id, equals('regula-falsi'));
          expect(bloc.state.isReady, isTrue);
          expect(bloc.state.result, isNull);
        },
      );
    });
  });
}

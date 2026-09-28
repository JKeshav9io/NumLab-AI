import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/error_mapper.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_result_model.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/domain/usecases/execute_solver_use_case.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';

class MockExecuteSolverUseCase extends Fake implements ExecuteSolverUseCase {
  int callCount = 0;
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
    callCount++;
    if (onCall != null) {
      return onCall!(
        solverId: solverId,
        payload: payload,
        accessToken: accessToken,
      );
    }
    throw UnimplementedError('onCall was not assigned');
  }
}

void main() {
  late MockExecuteSolverUseCase mockExecuteSolverUseCase;

  setUp(() {
    mockExecuteSolverUseCase = MockExecuteSolverUseCase();
  });

  group('Phase 2i — Solver Core Functional Hardening Tests', () {
    group('1. SolverInputFieldConfig Type Validation & Malformed Inputs', () {
      test('number field rejects non-numeric string inputs', () {
        const field = SolverInputFieldConfig(
          name: 'x0',
          label: 'Initial Guess',
          type: SolverInputFieldType.number,
        );

        expect(field.validate('abc'), 'Initial Guess must be a valid number');
        expect(
          field.validate('12.34.56'),
          'Initial Guess must be a valid number',
        );
        expect(field.validate('--5'), 'Initial Guess must be a valid number');
        expect(field.validate('  '), 'Initial Guess is required');
        expect(field.validate(null), 'Initial Guess is required');
        expect(field.validate('42.5'), isNull);
        expect(field.validate(42.5), isNull);
        expect(field.validate(-10), isNull);
      });

      test('integer field rejects decimals and invalid integer strings', () {
        const field = SolverInputFieldConfig(
          name: 'maxIterations',
          label: 'Max Iterations',
          type: SolverInputFieldType.integer,
          validation: SolverFieldValidation(minValue: 1, maxValue: 100),
        );

        expect(field.validate('abc'), 'Max Iterations must be a valid integer');
        expect(
          field.validate('3.14'),
          'Max Iterations must be a valid integer',
        );
        expect(field.validate(3.14), 'Max Iterations must be a valid integer');
        expect(field.validate(0), 'Max Iterations must be at least 1');
        expect(field.validate(150), 'Max Iterations must not exceed 100');
        expect(field.validate('50'), isNull);
        expect(field.validate(50), isNull);
      });

      test('vector field validates structure and element types', () {
        const field = SolverInputFieldConfig(
          name: 'constants',
          label: 'Constants Vector',
          type: SolverInputFieldType.vector,
        );

        expect(
          field.validate('not a list'),
          'Constants Vector must be a valid numeric vector',
        );
        expect(
          field.validate([1, 'abc', 3]),
          'Constants Vector elements must be valid numbers',
        );
        expect(field.validate([1, 2.5, 3]), isNull);
        expect(field.validate(['1', '2.5', '3']), isNull);
      });

      test(
        'matrix field validates 2D rectangular structure and numeric elements',
        () {
          const field = SolverInputFieldConfig(
            name: 'matrix',
            label: 'Coefficient Matrix',
            type: SolverInputFieldType.matrix,
          );

          expect(
            field.validate('raw invalid matrix string'),
            'Coefficient Matrix must be a valid numeric matrix',
          );
          expect(
            field.validate(['not a list row']),
            'Coefficient Matrix rows must be lists',
          );
          expect(
            field.validate([
              [1, 2],
              [3], // ragged row
            ]),
            'Coefficient Matrix rows must all have the same length (2)',
          );
          expect(
            field.validate([
              [1, 'abc'],
              [3, 4],
            ]),
            'Coefficient Matrix matrix cells must be valid numbers',
          );
          expect(
            field.validate([
              [1, 2],
              [3, 4],
            ]),
            isNull,
          );
        },
      );

      test(
        'pointList field validates coordinate maps and numeric coordinates',
        () {
          const field = SolverInputFieldConfig(
            name: 'points',
            label: 'Data Points',
            type: SolverInputFieldType.pointList,
          );

          expect(
            field.validate('invalid point data'),
            'Data Points must be a valid list of coordinates',
          );
          expect(
            field.validate(['not a map']),
            'Data Points items must be point objects with x and y coordinates',
          );
          expect(
            field.validate([
              {'x': 'bad', 'y': 2},
            ]),
            'Data Points points must contain valid numeric x coordinates',
          );
          expect(
            field.validate([
              {'x': 1, 'y': 'bad'},
            ]),
            'Data Points points must contain valid numeric y coordinates',
          );
          expect(
            field.validate([
              {'x': 1, 'y': 2},
              {'x': 2, 'y': 4},
            ]),
            isNull,
          );
        },
      );
    });

    group('2. Cross-Field Validation & Edge Cases', () {
      test('boundsOrderedRule validates stringified and numeric bounds', () {
        final bisection = SolverMethodRegistry.bisection;

        final invalidPayload = {
          'equation': 'x^2 - 4',
          'lowerBound': 5.0,
          'upperBound': 2.0,
        };
        final errors = bisection.validate(invalidPayload);
        expect(
          errors['bounds.ordered'],
          'lowerBound must be less than upperBound',
        );

        final stringPayload = {
          'equation': 'x^2 - 4',
          'lowerBound': '5.0',
          'upperBound': '2.0',
        };
        final stringErrors = bisection.validate(stringPayload);
        expect(
          stringErrors['bounds.ordered'],
          'lowerBound must be less than upperBound',
        );
      });

      test('uniquePointsXRule validates duplicate x values', () {
        final lagrange = SolverMethodRegistry.lagrangeInterpolation;

        final duplicatePoints = {
          'points': [
            {'x': 1.0, 'y': 2.0},
            {'x': 1.0, 'y': 5.0},
          ],
          'targetX': 1.5,
        };
        final errors = lagrange.validate(duplicatePoints);
        expect(errors['points.uniqueX'], 'x values must be unique');
      });

      test('odeStepSpecificationRule enforces either xn or steps', () {
        final euler = SolverMethodRegistry.euler;

        final neither = {
          'equation': 'x + y',
          'x0': 0.0,
          'y0': 1.0,
          'h': 0.1,
        };
        expect(
          euler.validate(neither)['ode.stepSpecification'],
          'either xn or steps is required',
        );

        final both = {
          'equation': 'x + y',
          'x0': 0.0,
          'y0': 1.0,
          'h': 0.1,
          'xn': 1.0,
          'steps': 10,
        };
        expect(
          euler.validate(both)['ode.stepSpecification'],
          'provide either xn or steps, not both',
        );

        final notMultiple = {
          'equation': 'x + y',
          'x0': 0.0,
          'y0': 1.0,
          'h': 0.3,
          'xn': 1.0, // (1 - 0) / 0.3 is not integer
        };
        expect(
          euler.validate(notMultiple)['ode.stepSpecification'],
          contains('exact positive multiple of h'),
        );
      });
    });

    group('3. SolverResult & SolverResultModel Resilience', () {
      test(
        'safely parses stringified numbers and booleans without TypeError',
        () {
          const rootResult = SolverResult(
            method: 'bisection',
            finalAnswer: {
              'root': '2.09455148',
              'converged': 'true',
              'error': '0.000045',
              'iterations': '18',
            },
          );

          expect(rootResult.root, closeTo(2.09455, 0.0001));
          expect(rootResult.isConverged, isTrue);
          expect(rootResult.error, closeTo(0.000045, 0.000001));
          expect(rootResult.iterationsCount, 18);
          expect(rootResult.resultValue, closeTo(2.09455, 0.0001));

          const interpResult = SolverResult(
            method: 'lagrange',
            finalAnswer: {
              'predictedY': '4.5512',
              'converged': 'true',
            },
          );
          expect(interpResult.resultValue, closeTo(4.5512, 0.0001));
        },
      );

      test(
        'SolverResultModel.fromJson parses nested meta, string explanation and execution times',
        () {
          final json = {
            'data': {
              'method': 'newton-raphson',
              'status': 'converged',
              'finalAnswer': {'root': 2.0},
              'explanation':
                  'Converged in 4 iterations using Newton-Raphson step.',
              'warnings': 'Non-fatal slope warning',
              'executionTimeMs': '15',
              'requestId': 'req-999',
              'timestamp': '2026-09-29T00:00:00Z',
            },
          };

          final model = SolverResultModel.fromJson(json);
          expect(model.method, 'newton-raphson');
          expect(model.status, 'converged');
          expect(model.root, 2.0);
          expect(
            model.explanation?.summary,
            contains('Converged in 4 iterations'),
          );
          expect(model.warnings, ['Non-fatal slope warning']);
          expect(model.executionTimeMs, 15);
          expect(model.requestId, 'req-999');
        },
      );

      test(
        'SolverResultModel.fromJson handles completely empty or missing optional fields',
        () {
          final json = <String, dynamic>{};
          final model = SolverResultModel.fromJson(json);

          expect(model.method, '');
          expect(model.finalAnswer, isEmpty);
          expect(model.iterations, isEmpty);
          expect(model.hasExplanation, isFalse);
          expect(model.hasWarnings, isFalse);
          expect(model.hasGraphData, isFalse);
          expect(model.executionTimeMs, 0);
        },
      );
    });

    group('4. Backend Error Mapping Hardening', () {
      test('maps 400 VALIDATION_ERROR with list of error items in details', () {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/solve/root/bisection'),
          response: Response(
            requestOptions: RequestOptions(path: '/solve/root/bisection'),
            statusCode: 400,
            data: {
              'success': false,
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Input validation failed',
                'details': [
                  {
                    'field': 'equation',
                    'message': 'Equation contains syntax error',
                  },
                ],
              },
            },
          ),
          type: DioExceptionType.badResponse,
        );

        final failure = mapExceptionToFailure(dioException);
        expect(failure, isA<ValidationFailure>());
        final valFailure = failure as ValidationFailure;
        expect(valFailure.fieldErrors.length, 1);
        expect(valFailure.fieldErrors.first.field, 'equation');
      });

      test('maps 400 VALIDATION_ERROR with errors key in details map', () {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/solve/root/bisection'),
          response: Response(
            requestOptions: RequestOptions(path: '/solve/root/bisection'),
            statusCode: 400,
            data: {
              'success': false,
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Input validation failed',
                'details': {
                  'errors': [
                    {'field': 'lowerBound', 'message': 'Invalid bound value'},
                  ],
                },
              },
            },
          ),
          type: DioExceptionType.badResponse,
        );

        final failure = mapExceptionToFailure(dioException);
        expect(failure, isA<ValidationFailure>());
        final valFailure = failure as ValidationFailure;
        expect(valFailure.fieldErrors.first.field, 'lowerBound');
      });

      test('maps Dio connection timeouts to NetworkFailure', () {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/solve/root/bisection'),
          type: DioExceptionType.connectionTimeout,
        );

        final failure = mapExceptionToFailure(dioException);
        expect(failure, isA<NetworkFailure>());
        expect(failure.message, contains('Unable to connect'));
      });
    });

    group('5. SolverFormBloc Lifecycle, Rapid Submit & Reset Hardening', () {
      test(
        'unknown solver ID emits failure with UNKNOWN_SOLVER_METHOD',
        () async {
          final bloc =
              SolverFormBloc(
                executeSolverUseCase: mockExecuteSolverUseCase,
              )..add(
                const SolverFormLoadStarted(solverId: 'non-existent-solver'),
              );

          await expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<SolverFormState>((s) => s.isLoadingConfig),
              predicate<SolverFormState>(
                (s) =>
                    s.isFailure &&
                    s.failure?.code == 'UNKNOWN_SOLVER_METHOD' &&
                    s.config == null,
              ),
            ]),
          );

          await bloc.close();
        },
      );

      test(
        'rapid duplicate submissions while submitting are discarded',
        () async {
          const tResult = SolverResult(
            method: 'Bisection Method',
            finalAnswer: {'root': 2.0945},
          );

          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async {
                await Future<void>.delayed(const Duration(milliseconds: 50));
                return const Right(tResult);
              };

          final bloc =
              SolverFormBloc(
                executeSolverUseCase: mockExecuteSolverUseCase,
              )..add(
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

          final expectation = expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<SolverFormState>((s) => s.isSubmitting),
              predicate<SolverFormState>(
                (s) => s.isSuccess && s.result == tResult,
              ),
            ]),
          );

          // Dispatch 3 rapid submissions in immediate succession
          bloc
            ..add(const SolverFormSubmitted())
            ..add(const SolverFormSubmitted())
            ..add(const SolverFormSubmitted());

          await expectation;

          // Verify use case was invoked only ONCE despite rapid submissions
          expect(mockExecuteSolverUseCase.callCount, 1);

          await bloc.close();
        },
      );

      test(
        're-execution after failure clears previous failure before emitting new state',
        () async {
          const tResult = SolverResult(
            method: 'Bisection Method',
            finalAnswer: {'root': 2.0945},
          );

          // First execution fails with ServerFailure
          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async =>
                  const Left(ServerFailure(message: 'Math domain error'));

          final bloc =
              SolverFormBloc(
                executeSolverUseCase: mockExecuteSolverUseCase,
              )..add(
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

          final failExpectation = expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<SolverFormState>((s) => s.isSubmitting),
              predicate<SolverFormState>(
                (s) => s.isFailure && s.errorMessage == 'Math domain error',
              ),
            ]),
          );
          bloc.add(const SolverFormSubmitted());
          await failExpectation;

          // Second execution succeeds
          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async => const Right(tResult);

          final successExpectation = expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<SolverFormState>(
                (s) => s.isSubmitting && s.failure == null,
              ),
              predicate<SolverFormState>(
                (s) => s.isSuccess && s.result == tResult,
              ),
            ]),
          );

          bloc.add(const SolverFormSubmitted());
          await successExpectation;

          expect(bloc.state.isSuccess, isTrue);
          expect(bloc.state.failure, isNull);
          expect(bloc.state.errorMessage, isNull);
          expect(bloc.state.result?.root, closeTo(2.0945, 0.001));

          await bloc.close();
        },
      );

      test(
        'form reset restores exact schema defaults and purges stale result/errors',
        () async {
          final bisection = SolverMethodRegistry.bisection;
          const tResult = SolverResult(
            method: 'Bisection Method',
            finalAnswer: {'root': 2.0945},
          );

          mockExecuteSolverUseCase.onCall =
              ({
                required solverId,
                required payload,
                accessToken,
              }) async => const Right(tResult);

          final bloc =
              SolverFormBloc(
                executeSolverUseCase: mockExecuteSolverUseCase,
              )..add(
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

          // Modify a field value
          bloc.add(
            const SolverFormFieldChanged(fieldName: 'lowerBound', value: 1.2),
          );
          await bloc.stream.firstWhere((s) => s.getValue('lowerBound') == 1.2);

          // Submit and obtain result
          final submitExpectation = expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<SolverFormState>((s) => s.isSubmitting),
              predicate<SolverFormState>((s) => s.isSuccess && s.hasResult),
            ]),
          );
          bloc.add(const SolverFormSubmitted());
          await submitExpectation;

          // Request Reset
          final resetExpectation = expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<SolverFormState>(
                (s) =>
                    s.isReady &&
                    !s.hasResult &&
                    s.failure == null &&
                    s.fieldErrors.isEmpty &&
                    s.getValue('lowerBound') ==
                        bisection.defaultPayload()['lowerBound'],
              ),
            ]),
          );
          bloc.add(const SolverFormResetRequested());
          await resetExpectation;

          await bloc.close();
        },
      );
    });

    group('6. All 27 Solvers Configuration & Valid Payload Integrity', () {
      test(
        'all 27 solver configurations pass validation with valid representative payloads',
        () {
          for (final config in SolverMethodRegistry.all) {
            final payload = _generateValidPayloadForConfig(config);
            final errors = config.validate(payload);

            expect(
              errors,
              isEmpty,
              reason:
                  'Representative payload for ${config.id} must be valid without errors. Found: $errors',
            );
          }
        },
      );
    });
  });
}

Map<String, dynamic> _generateValidPayloadForConfig(SolverMethodConfig config) {
  final payload = config.defaultPayload();

  switch (config.category) {
    case SolverCategory.rootFinding:
      payload['equation'] = 'x^3 - x - 2';
      if (config.id == 'newton-raphson') {
        payload['initialGuess'] = 1.5;
        payload['derivativeEquation'] = '3*x^2 - 1';
      } else if (config.id == 'secant') {
        payload['firstGuess'] = 1.0;
        payload['secondGuess'] = 2.0;
      } else {
        payload['lowerBound'] = 1.0;
        payload['upperBound'] = 2.0;
      }
      payload['tolerance'] = 0.0001;
      payload['maxIterations'] = 100;

    case SolverCategory.linearAlgebra:
      payload['matrix'] = [
        [4.0, 1.0],
        [1.0, 3.0],
      ];
      payload['constants'] = [1.0, 2.0];
      if (config.id == 'jacobi' || config.id == 'gauss-seidel') {
        payload['initialGuess'] = [0.0, 0.0];
        payload['tolerance'] = 0.0001;
        payload['maxIterations'] = 100;
      }

    case SolverCategory.interpolation:
      payload['targetX'] = 2.5;
      if (config.id == 'central-difference') {
        payload['points'] = [
          {'x': 1.0, 'y': 2.0},
          {'x': 2.0, 'y': 4.0},
          {'x': 3.0, 'y': 8.0},
          {'x': 4.0, 'y': 16.0},
        ];
        payload['variant'] = 'stirling';
      } else if (config.id == 'quadratic' ||
          config.id == 'natural-cubic-spline') {
        payload['points'] = [
          {'x': 1.0, 'y': 1.0},
          {'x': 2.0, 'y': 4.0},
          {'x': 3.0, 'y': 9.0},
        ];
      } else {
        payload['points'] = [
          {'x': 1.0, 'y': 1.0},
          {'x': 2.0, 'y': 4.0},
          {'x': 3.0, 'y': 9.0},
        ];
      }

    case SolverCategory.ode:
      payload['equation'] = 'x + y';
      payload['x0'] = 0.0;
      payload['y0'] = 1.0;
      payload['h'] = 0.1;
      if (config.id == 'milne') {
        payload['steps'] = 10;
      } else {
        payload['xn'] = 1.0;
      }

    case SolverCategory.integration:
      payload['equation'] = 'x^2';
      payload['lowerBound'] = 0.0;
      payload['upperBound'] = 2.0;
      if (config.id == 'gauss-legendre') {
        payload['points'] = 3;
      } else if (config.id == 'simpson-38') {
        payload['subintervals'] = 99;
      } else if (config.id == 'simpson-13') {
        payload['subintervals'] = 100;
      } else {
        payload['subintervals'] = 100;
      }

    case SolverCategory.differentiation:
      if (config.id == 'function-finite-difference') {
        payload['equation'] = 'x^3';
        payload['targetX'] = 2.0;
        payload['h'] = 0.01;
        payload['variant'] = 'central';
      } else if (config.id == 'forward-difference') {
        payload['points'] = [
          {'x': 1.0, 'y': 1.0},
          {'x': 2.0, 'y': 4.0},
          {'x': 3.0, 'y': 9.0},
        ];
        payload['targetX'] = 1.0;
      } else if (config.id == 'backward-difference') {
        payload['points'] = [
          {'x': 1.0, 'y': 1.0},
          {'x': 2.0, 'y': 4.0},
          {'x': 3.0, 'y': 9.0},
        ];
        payload['targetX'] = 3.0;
      } else if (config.id == 'central-difference-tabular') {
        payload['points'] = [
          {'x': 1.0, 'y': 1.0},
          {'x': 2.0, 'y': 4.0},
          {'x': 3.0, 'y': 9.0},
        ];
        payload['targetX'] = 2.0;
      } else {
        payload['points'] = [
          {'x': 1.0, 'y': 1.0},
          {'x': 2.0, 'y': 4.0},
          {'x': 3.0, 'y': 9.0},
        ];
        payload['targetX'] = 2.0;
      }
  }

  return payload;
}

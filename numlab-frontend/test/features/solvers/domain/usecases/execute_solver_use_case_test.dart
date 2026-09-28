import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/entities.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/domain/repositories/solver_repository.dart';
import 'package:numlab_frontend/features/solvers/domain/usecases/usecases.dart';

class MockSolverRepository extends Fake implements SolverRepository {
  Future<Either<Failure, SolverResult>> Function({
    required SolverMethodConfig config,
    required Map<String, dynamic> payload,
    String? accessToken,
  })?
  onSolve;

  @override
  Future<Either<Failure, SolverResult>> solve({
    required SolverMethodConfig config,
    required Map<String, dynamic> payload,
    String? accessToken,
  }) {
    return onSolve!(
      config: config,
      payload: payload,
      accessToken: accessToken,
    );
  }
}

void main() {
  late MockSolverRepository mockRepository;
  late ExecuteSolverUseCase useCase;

  const sampleResult = SolverResult(
    method: 'Bisection Method',
    status: 'converged',
    input: {'equation': 'x^2 - 4'},
    finalAnswer: {'root': 2.0, 'converged': true},
  );

  setUp(() {
    mockRepository = MockSolverRepository();
    useCase = ExecuteSolverUseCase(mockRepository);
  });

  group('ExecuteSolverUseCase — Execution Flow & Lookup', () {
    test('successfully resolves solver by ID and executes', () async {
      SolverMethodConfig? capturedConfig;
      Map<String, dynamic>? capturedPayload;

      mockRepository.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            capturedConfig = config;
            capturedPayload = payload;
            return const Right(sampleResult);
          };

      final validPayload = {
        'equation': 'x^3 - x - 2',
        'lowerBound': 1.0,
        'upperBound': 2.0,
        'tolerance': 0.0001,
        'maxIterations': 100,
      };

      final result = await useCase(
        solverId: 'bisection',
        payload: validPayload,
      );

      expect(result, const Right<Failure, SolverResult>(sampleResult));
      expect(capturedConfig?.id, 'bisection');
      expect(capturedPayload?['equation'], 'x^3 - x - 2');
    });

    test('successfully resolves solver by API endpoint path', () async {
      mockRepository.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            return const Right(sampleResult);
          };

      final result = await useCase(
        solverId: '/solve/root/bisection',
        payload: {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
        },
      );

      expect(result.isRight(), isTrue);
    });

    test(
      'returns ValidationFailure without invoking repository for unknown solver ID',
      () async {
        var repositoryCalled = false;
        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              repositoryCalled = true;
              return const Right(sampleResult);
            };

        final result = await useCase(
          solverId: 'non_existent_solver_id',
          payload: {'equation': 'x^2 - 4'},
        );

        expect(repositoryCalled, isFalse);
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            expect(
              failure.message,
              contains('Unknown solver method: "non_existent_solver_id"'),
            );
            expect(failure.code, 'UNKNOWN_SOLVER_METHOD');
          },
          (_) => fail('Expected Left<ValidationFailure>'),
        );
      },
    );
  });

  group('ExecuteSolverUseCase — Input Validation & Cross-Field Rules', () {
    test(
      'returns ValidationFailure for missing required fields without calling repository',
      () async {
        var repositoryCalled = false;
        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              repositoryCalled = true;
              return const Right(sampleResult);
            };

        // Missing equation and upperBound for bisection
        final invalidPayload = {
          'lowerBound': 1.0,
        };

        final result = await useCase(
          solverId: 'bisection',
          payload: invalidPayload,
        );

        expect(repositoryCalled, isFalse);
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            final valFail = failure as ValidationFailure;
            expect(valFail.fieldErrors, isNotEmpty);
            final fieldNames = valFail.fieldErrors.map((e) => e.field).toSet();
            expect(fieldNames.contains('equation'), isTrue);
            expect(fieldNames.contains('upperBound'), isTrue);
          },
          (_) => fail('Expected validation failure'),
        );
      },
    );

    test(
      'returns ValidationFailure when cross-field relational rule fails',
      () async {
        var repositoryCalled = false;
        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              repositoryCalled = true;
              return const Right(sampleResult);
            };

        // Invalid: lowerBound (5.0) >= upperBound (2.0)
        final invalidInterval = {
          'equation': 'x^3 - x - 2',
          'lowerBound': 5.0,
          'upperBound': 2.0,
        };

        final result = await useCase(
          solverId: 'bisection',
          payload: invalidInterval,
        );

        expect(repositoryCalled, isFalse);
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            final valFail = failure as ValidationFailure;
            expect(
              valFail.fieldErrors.any(
                (e) =>
                    e.message.contains('must be strictly less than') ||
                    e.message.contains('must be less than'),
              ),
              isTrue,
            );
          },
          (_) => fail('Expected cross-field rule failure'),
        );
      },
    );

    test(
      'returns ValidationFailure for out-of-bounds numeric fields (tolerance <= 0)',
      () async {
        var repositoryCalled = false;
        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              repositoryCalled = true;
              return const Right(sampleResult);
            };

        final invalidTolerance = {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
          'tolerance': -0.05,
        };

        final result = await useCase(
          solverId: 'bisection',
          payload: invalidTolerance,
        );

        expect(repositoryCalled, isFalse);
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            final valFail = failure as ValidationFailure;
            expect(
              valFail.fieldErrors.any((e) => e.field == 'tolerance'),
              isTrue,
            );
          },
          (_) => fail('Expected validation failure for negative tolerance'),
        );
      },
    );
  });

  group(
    'ExecuteSolverUseCase — Repository Delegation & Auth Token Forwarding',
    () {
      test('forwards explicitly passed accessToken to repository', () async {
        String? receivedToken;

        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              receivedToken = accessToken;
              return const Right(sampleResult);
            };

        await useCase(
          solverId: 'bisection',
          payload: {
            'equation': 'x^3 - x - 2',
            'lowerBound': 1.0,
            'upperBound': 2.0,
          },
          accessToken: 'user_bearer_token_123',
        );

        expect(receivedToken, 'user_bearer_token_123');
      });

      test(
        'supports anonymous solver execution when accessToken is omitted',
        () async {
          String? receivedToken = 'sentinel';

          mockRepository.onSolve =
              ({
                required config,
                required payload,
                accessToken,
              }) async {
                receivedToken = accessToken;
                return const Right(sampleResult);
              };

          await useCase(
            solverId: 'bisection',
            payload: {
              'equation': 'x^3 - x - 2',
              'lowerBound': 1.0,
              'upperBound': 2.0,
            },
          );

          expect(receivedToken, isNull);
        },
      );
    },
  );

  group('ExecuteSolverUseCase — Repository Failure Propagation', () {
    test('propagates NetworkFailure as Left', () async {
      mockRepository.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            return const Left<Failure, SolverResult>(
              NetworkFailure(message: 'Connection timed out'),
            );
          };

      final result = await useCase(
        solverId: 'bisection',
        payload: {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
        },
      );

      expect(
        result,
        const Left<Failure, SolverResult>(
          NetworkFailure(message: 'Connection timed out'),
        ),
      );
    });

    test('propagates ServerFailure as Left', () async {
      mockRepository.onSolve =
          ({
            required config,
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

      final result = await useCase(
        solverId: 'bisection',
        payload: {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
        },
      );

      expect(
        result,
        const Left<Failure, SolverResult>(
          ServerFailure(
            message: 'Internal math calculation error',
            statusCode: 500,
          ),
        ),
      );
    });

    test('propagates AuthFailure as Left', () async {
      mockRepository.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            return const Left<Failure, SolverResult>(
              AuthFailure(message: 'Invalid or expired session'),
            );
          };

      final result = await useCase(
        solverId: 'bisection',
        payload: {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
        },
      );

      expect(
        result,
        const Left<Failure, SolverResult>(
          AuthFailure(message: 'Invalid or expired session'),
        ),
      );
    });

    test('propagates RateLimitFailure as Left', () async {
      mockRepository.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            return const Left<Failure, SolverResult>(
              RateLimitFailure(
                message: 'Too many requests',
                retryAfterSeconds: 30,
              ),
            );
          };

      final result = await useCase(
        solverId: 'bisection',
        payload: {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
        },
      );

      expect(
        result,
        const Left<Failure, SolverResult>(
          RateLimitFailure(message: 'Too many requests', retryAfterSeconds: 30),
        ),
      );
    });
  });

  group('ExecuteSolverUseCase — Representative Solvers from Each Category', () {
    test('1. Root Finding: Newton-Raphson executes successfully', () async {
      mockRepository.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            expect(config.id, 'newton-raphson');
            return const Right(
              SolverResult(
                method: 'Newton-Raphson Method',
                finalAnswer: {'root': 1.4142, 'converged': true},
              ),
            );
          };

      final result = await useCase(
        solverId: 'newton-raphson',
        payload: {
          'equation': 'x^2 - 2',
          'derivativeEquation': '2*x',
          'initialGuess': 1.0,
        },
      );

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).root, 1.4142);
    });

    test('2. Linear Algebra: Jacobi Method executes successfully', () async {
      mockRepository.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            expect(config.id, 'jacobi');
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

      final result = await useCase(
        solverId: 'jacobi',
        payload: {
          'matrix': [
            [4.0, 1.0],
            [1.0, 3.0],
          ],
          'constants': [1.0, 2.0],
          'initialGuess': [0.0, 0.0],
          'tolerance': 0.001,
          'maxIterations': 50,
        },
      );

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).solutionVector, [
        1.0,
        2.0,
      ]);
    });

    test(
      '3. Interpolation: Lagrange Interpolation executes successfully',
      () async {
        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              expect(config.id, 'lagrange');
              return const Right(
                SolverResult(
                  method: 'Lagrange Interpolation',
                  finalAnswer: {'interpolatedValue': 8.0},
                ),
              );
            };

        final result = await useCase(
          solverId: 'lagrange',
          payload: {
            'points': [
              {'x': 1.0, 'y': 2.0},
              {'x': 2.0, 'y': 4.0},
              {'x': 3.0, 'y': 8.0},
            ],
            'targetX': 3.0,
          },
        );

        expect(result.isRight(), isTrue);
        expect(result.getOrElse((_) => throw Exception()).resultValue, 8.0);
      },
    );

    test(
      '4. Differential Equations: Runge-Kutta 4th Order executes successfully',
      () async {
        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              expect(config.id, 'rk4');
              return const Right(
                SolverResult(
                  method: 'Runge-Kutta 4th Order',
                  finalAnswer: {'yEnd': 2.71828},
                ),
              );
            };

        final result = await useCase(
          solverId: 'rk4',
          payload: {
            'equation': 'x + y',
            'x0': 0.0,
            'y0': 1.0,
            'h': 0.1,
            'xn': 1.0,
          },
        );

        expect(result.isRight(), isTrue);
      },
    );

    test(
      '5. Numerical Integration: Simpson 1/3 Rule executes successfully',
      () async {
        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              expect(config.id, 'simpson-13');
              return const Right(
                SolverResult(
                  method: "Simpson's 1/3 Rule",
                  finalAnswer: {'integral': 2.0},
                ),
              );
            };

        final result = await useCase(
          solverId: 'simpson-13',
          payload: {
            'equation': 'sin(x)',
            'lowerBound': 0.0,
            'upperBound': 3.14159,
            'subintervals': 100,
          },
        );

        expect(result.isRight(), isTrue);
        expect(result.getOrElse((_) => throw Exception()).resultValue, 2.0);
      },
    );

    test(
      '6. Numerical Differentiation: Central Difference executes successfully',
      () async {
        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              expect(config.id, 'central-difference-tabular');
              return const Right(
                SolverResult(
                  method: 'Central Difference Differentiation',
                  finalAnswer: {'derivative': 4.0},
                ),
              );
            };

        final result = await useCase(
          solverId: 'central-difference-tabular',
          payload: {
            'points': [
              {'x': 1.0, 'y': 1.0},
              {'x': 2.0, 'y': 4.0},
              {'x': 3.0, 'y': 9.0},
            ],
            'targetX': 2.0,
          },
        );

        expect(result.isRight(), isTrue);
        expect(result.getOrElse((_) => throw Exception()).resultValue, 4.0);
      },
    );
  });

  group('ExecuteSolverUseCase — Comprehensive 27 Solver Registry Coverage', () {
    test(
      'all 27 solvers in registry can be validated and executed via default/valid payloads',
      () async {
        final executedSolvers = <String>[];

        mockRepository.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              executedSolvers.add(config.id);
              return Right(
                SolverResult(
                  method: config.name,
                  finalAnswer: const {'success': true},
                ),
              );
            };

        for (final config in SolverMethodRegistry.all) {
          final payload = _generateValidPayloadForConfig(config);
          final result = await useCase(
            solverId: config.id,
            payload: payload,
          );

          expect(
            result.isRight(),
            isTrue,
            reason:
                'Solver "${config.id}" failed validation on valid payload. Errors: '
                '${result.fold((f) => (f as ValidationFailure).fieldErrors.map((e) => "${e.field}: ${e.message}").join(", "), (_) => "")}',
          );
        }

        expect(executedSolvers.length, 27);
        expect(executedSolvers.toSet().length, 27);
      },
    );
  });

  group('ExecuteSolverUseCase — Direct Config Execution & Alias', () {
    test('executeWithConfig executes valid config directly', () async {
      mockRepository.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            return const Right(sampleResult);
          };

      final result = await useCase.executeWithConfig(
        config: SolverMethodRegistry.bisection,
        payload: {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
        },
      );

      expect(result.isRight(), isTrue);
    });

    test(
      'executeWithConfig returns ValidationFailure for invalid payload',
      () async {
        final result = await useCase.executeWithConfig(
          config: SolverMethodRegistry.bisection,
          payload: {
            'equation': 'x^3 - x - 2',
            'lowerBound': 2.0,
            'upperBound': 1.0, // invalid
          },
        );

        expect(result.isLeft(), isTrue);
      },
    );

    test('execute alias produces identical result to call', () async {
      mockRepository.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            return const Right(sampleResult);
          };

      final result = await useCase.execute(
        solverId: 'bisection',
        payload: const {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
        },
      );

      expect(result, const Right<Failure, SolverResult>(sampleResult));
    });
  });
}

/// Helper building valid test payloads for any registered solver.
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

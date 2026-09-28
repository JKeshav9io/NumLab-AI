import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/entities.dart';

void main() {
  group('SolverExplanation Entity', () {
    test('instantiates with summary and steps', () {
      const explanation = SolverExplanation(
        summary: 'Bisection converged after 14 iterations.',
        steps: [
          'Choose interval [1.0, 2.0]',
          'Compute midpoint c = 1.5',
          'Evaluate f(1.5)',
        ],
      );

      expect(
        explanation.summary,
        'Bisection converged after 14 iterations.',
      );
      expect(explanation.steps.length, 3);
      expect(explanation.steps.first, 'Choose interval [1.0, 2.0]');
    });

    test('value equality works as expected for Equatable', () {
      const exp1 = SolverExplanation(
        summary: 'Same summary',
        steps: ['step 1', 'step 2'],
      );
      const exp2 = SolverExplanation(
        summary: 'Same summary',
        steps: ['step 1', 'step 2'],
      );
      const exp3 = SolverExplanation(
        summary: 'Different summary',
        steps: ['step 1'],
      );

      expect(exp1, equals(exp2));
      expect(exp1, isNot(equals(exp3)));
    });
  });

  group('SolverResult Entity', () {
    const sampleExplanation = SolverExplanation(
      summary: 'Converged successfully.',
      steps: ['Step 1: Set x0 = 1.5'],
    );

    const fullResult = SolverResult(
      method: 'Bisection Method',
      status: 'converged',
      input: {
        'equation': 'x^3 - x - 2',
        'lowerBound': 1.0,
        'upperBound': 2.0,
      },
      iterations: [
        {'iteration': 1, 'a': 1.0, 'b': 2.0, 'c': 1.5, 'error': 0.5},
      ],
      finalAnswer: {
        'root': 1.5214,
        'functionValue': -0.00003,
        'iterationsUsed': 14,
        'converged': true,
        'estimatedError': 0.00005,
      },
      explanation: sampleExplanation,
      graphData: [
        {'x': 1.0, 'y': -2.0},
        {'x': 2.0, 'y': 4.0},
      ],
      warnings: ['Function slope is steep near interval boundary.'],
      executionTimeMs: 14,
      requestId: 'req-abc-123',
      timestamp: '2026-09-28T12:00:00Z',
    );

    test('holds all constructor values accurately', () {
      expect(fullResult.method, 'Bisection Method');
      expect(fullResult.status, 'converged');
      expect(fullResult.input['equation'], 'x^3 - x - 2');
      expect(fullResult.iterations.length, 1);
      expect(fullResult.finalAnswer['root'], 1.5214);
      expect(fullResult.explanation, sampleExplanation);
      expect(fullResult.graphData, isNotNull);
      expect(fullResult.warnings.length, 1);
      expect(fullResult.executionTimeMs, 14);
      expect(fullResult.requestId, 'req-abc-123');
      expect(fullResult.timestamp, '2026-09-28T12:00:00Z');
    });

    test('default parameters are initialized gracefully', () {
      const minimal = SolverResult(
        method: 'Secant Method',
        finalAnswer: {'root': 1.414},
      );

      expect(minimal.status, isNull);
      expect(minimal.input, isEmpty);
      expect(minimal.iterations, isEmpty);
      expect(minimal.explanation, isNull);
      expect(minimal.graphData, isNull);
      expect(minimal.warnings, isEmpty);
      expect(minimal.executionTimeMs, 0);
      expect(minimal.requestId, isNull);
      expect(minimal.timestamp, isNull);
    });

    group('isConverged helper', () {
      test('returns true when finalAnswer["converged"] is true', () {
        const res = SolverResult(
          method: 'Newton',
          finalAnswer: {'converged': true},
        );
        expect(res.isConverged, isTrue);
      });

      test('returns false when finalAnswer["converged"] is false', () {
        const res = SolverResult(
          method: 'Newton',
          status: 'converged',
          finalAnswer: {'converged': false},
        );
        expect(res.isConverged, isFalse);
      });

      test(
        'falls back to status == "converged" when finalAnswer has no converged key',
        () {
          const res1 = SolverResult(
            method: 'Jacobi',
            status: 'converged',
            finalAnswer: {'iterations': 5},
          );
          expect(res1.isConverged, isTrue);

          const res2 = SolverResult(
            method: 'Jacobi',
            status: 'max_iterations_reached',
            finalAnswer: {'iterations': 100},
          );
          expect(res2.isConverged, isFalse);
        },
      );
    });

    group('convenience mathematical accessors', () {
      test('root accessor extracts root from finalAnswer', () {
        expect(fullResult.root, 1.5214);

        const noRoot = SolverResult(
          method: 'Gauss-Jordan',
          finalAnswer: {
            'solution': [1, 2, 3],
          },
        );
        expect(noRoot.root, isNull);
      });

      test('solutionVector accessor extracts linear solution vector', () {
        const linear = SolverResult(
          method: 'Gauss Elimination',
          finalAnswer: {
            'solution': [2.0, -1.0, 3.5],
          },
        );
        expect(linear.solutionVector, [2.0, -1.0, 3.5]);
        expect(fullResult.solutionVector, isNull);
      });

      test(
        'resultValue extracts scalar result across various domain solvers',
        () {
          const integral = SolverResult(
            method: 'Simpson 1/3',
            finalAnswer: {'integral': 3.14159},
          );
          expect(integral.resultValue, 3.14159);

          const diff = SolverResult(
            method: 'Central Difference',
            finalAnswer: {'derivative': 4.0},
          );
          expect(diff.resultValue, 4.0);

          const interp = SolverResult(
            method: 'Lagrange Interpolation',
            finalAnswer: {'interpolatedValue': 12.75},
          );
          expect(interp.resultValue, 12.75);

          const generic = SolverResult(
            method: 'Generic Method',
            finalAnswer: {'result': 42.0},
          );
          expect(generic.resultValue, 42.0);

          expect(fullResult.resultValue, 1.5214);
        },
      );

      test(
        'error extracts estimated or calculated error across field names',
        () {
          expect(fullResult.error, 0.00005);

          const res1 = SolverResult(
            method: 'Test',
            finalAnswer: {'error': 0.001},
          );
          expect(res1.error, 0.001);

          const res2 = SolverResult(
            method: 'Test',
            finalAnswer: {'approximateError': 0.002},
          );
          expect(res2.error, 0.002);

          const res3 = SolverResult(
            method: 'Test',
            finalAnswer: {'trueError': 0.00001},
          );
          expect(res3.error, 0.00001);
        },
      );

      test(
        'iterationsCount resolves count from various finalAnswer formats or iterations list',
        () {
          expect(fullResult.iterationsCount, 14);

          const res1 = SolverResult(
            method: 'Test',
            finalAnswer: {'iterations': 20},
          );
          expect(res1.iterationsCount, 20);

          const res2 = SolverResult(
            method: 'Test',
            finalAnswer: {'iterationCount': 8},
          );
          expect(res2.iterationsCount, 8);

          const res3 = SolverResult(
            method: 'Test',
            iterations: [1, 2, 3, 4],
            finalAnswer: {},
          );
          expect(res3.iterationsCount, 4);

          const res4 = SolverResult(
            method: 'Test',
            finalAnswer: {},
          );
          expect(res4.iterationsCount, isNull);
        },
      );
    });

    group('boolean content flags', () {
      test(
        'hasGraphData correctly detects present vs empty or null graph data',
        () {
          expect(fullResult.hasGraphData, isTrue);

          const resNull = SolverResult(
            method: 'Test',
            finalAnswer: {},
          );
          expect(resNull.hasGraphData, isFalse);

          const resEmptyList = SolverResult(
            method: 'Test',
            finalAnswer: {},
            graphData: <dynamic>[],
          );
          expect(resEmptyList.hasGraphData, isFalse);

          const resEmptyMap = SolverResult(
            method: 'Test',
            finalAnswer: {},
            graphData: <String, dynamic>{},
          );
          expect(resEmptyMap.hasGraphData, isFalse);
        },
      );

      test(
        'hasExplanation correctly detects presence of non-empty explanation',
        () {
          expect(fullResult.hasExplanation, isTrue);

          const resNull = SolverResult(
            method: 'Test',
            finalAnswer: {},
          );
          expect(resNull.hasExplanation, isFalse);

          const resEmpty = SolverResult(
            method: 'Test',
            finalAnswer: {},
            explanation: SolverExplanation(summary: '', steps: []),
          );
          expect(resEmpty.hasExplanation, isFalse);
        },
      );

      test('hasWarnings detects presence of warning messages', () {
        expect(fullResult.hasWarnings, isTrue);

        const resNoWarnings = SolverResult(
          method: 'Test',
          finalAnswer: {},
        );
        expect(resNoWarnings.hasWarnings, isFalse);
      });

      test('hasIterations detects non-empty iterations list', () {
        expect(fullResult.hasIterations, isTrue);

        const resNoIter = SolverResult(
          method: 'Test',
          finalAnswer: {},
        );
        expect(resNoIter.hasIterations, isFalse);
      });
    });

    test('value equality holds for identical SolverResult instances', () {
      const r1 = SolverResult(
        method: 'Euler',
        finalAnswer: {'y': 2.5},
      );
      const r2 = SolverResult(
        method: 'Euler',
        finalAnswer: {'y': 2.5},
      );
      const r3 = SolverResult(
        method: 'RK4',
        finalAnswer: {'y': 2.5},
      );

      expect(r1, equals(r2));
      expect(r1, isNot(equals(r3)));
    });
  });
}

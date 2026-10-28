import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_explanation.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

void main() {
  group('HistoryRun.toSolverResult() domain conversion', () {
    final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');

    test('converts full valid outputPayload to SolverResult', () {
      final run = HistoryRun(
        id: 'run-uuid-123',
        userId: 'user-456',
        method: 'root/bisection',
        inputPayload: const {
          'equation': 'x^2 - 4',
          'a': 0.0,
          'b': 3.0,
        },
        outputPayload: const {
          'method': 'Bisection Method',
          'status': 'converged',
          'input': {
            'equation': 'x^2 - 4',
            'a': 0.0,
            'b': 3.0,
          },
          'iterations': [
            {'iteration': 1, 'c': 1.5, 'error': 0.5},
            {'iteration': 2, 'c': 2.0, 'error': 0.0},
          ],
          'finalAnswer': {
            'root': 2.0,
            'converged': true,
          },
          'graphData': [
            {'x': 0.0, 'y': -4.0},
            {'x': 2.0, 'y': 0.0},
            {'x': 3.0, 'y': 5.0},
          ],
          'warnings': ['Approaching near-zero derivative'],
          'executionTimeMs': 42,
          'explanation': {
            'summary': 'Root found at x = 2.0',
            'steps': ['Initial interval [0, 3]', 'Midpoint evaluated to 1.5'],
          },
        },
        createdAt: timestamp,
      );

      final result = run.toSolverResult();

      expect(result, isA<SolverResult>());
      expect(result.method, 'Bisection Method');
      expect(result.status, 'converged');
      expect(result.input, {
        'equation': 'x^2 - 4',
        'a': 0.0,
        'b': 3.0,
      });
      expect(result.iterations.length, 2);
      expect(result.finalAnswer, {
        'root': 2.0,
        'converged': true,
      });
      expect(result.warnings, ['Approaching near-zero derivative']);
      expect(result.executionTimeMs, 42);
      expect(result.requestId, 'run-uuid-123');
      expect(result.timestamp, '2026-09-30T10:00:00.000Z');
      expect(result.explanation, isA<SolverExplanation>());
      expect(result.explanation?.summary, 'Root found at x = 2.0');
      expect(result.explanation?.steps, [
        'Initial interval [0, 3]',
        'Midpoint evaluated to 1.5',
      ]);
      expect(result.graphData, isNotNull);
    });

    test(
      'falls back to HistoryRun.method when method is omitted from outputPayload',
      () {
        final run = HistoryRun(
          id: 'run-fallback-method',
          method: 'ode/runge-kutta-4',
          outputPayload: const {
            'status': 'success',
            'finalAnswer': {'y': 4.5},
          },
          createdAt: timestamp,
        );

        final result = run.toSolverResult();

        expect(result.method, 'ode/runge-kutta-4');
        expect(result.status, 'success');
        expect(result.finalAnswer, {'y': 4.5});
      },
    );

    test(
      'falls back to inputPayload when outputPayload input is missing or empty',
      () {
        final inputData = {
          'matrix': [
            [1, 2],
            [3, 4],
          ],
          'b': [5, 6],
        };
        final run = HistoryRun(
          id: 'run-fallback-input',
          method: 'linear/gaussian-elimination',
          inputPayload: inputData,
          outputPayload: const {
            'status': 'converged',
            'finalAnswer': {
              'x': [1.0, 2.0],
            },
          },
          createdAt: timestamp,
        );

        final result = run.toSolverResult();

        expect(result.input, inputData);
      },
    );

    test('resolves finalAnswer from result or solution keys', () {
      final runWithResult = HistoryRun(
        id: 'run-result-key',
        method: 'roots/secant',
        outputPayload: const {
          'result': {'root': 1.414},
        },
        createdAt: timestamp,
      );
      expect(runWithResult.toSolverResult().finalAnswer, {'root': 1.414});

      final runWithSolution = HistoryRun(
        id: 'run-solution-key',
        method: 'system/jacobi',
        outputPayload: const {
          'solution': {'x1': 1.0, 'x2': 2.0},
        },
        createdAt: timestamp,
      );
      expect(runWithSolution.toSolverResult().finalAnswer, {
        'x1': 1.0,
        'x2': 2.0,
      });

      final runWithListSolution = HistoryRun(
        id: 'run-list-solution',
        method: 'system/gauss-seidel',
        outputPayload: const {
          'solution': [1.0, 2.0, 3.0],
        },
        createdAt: timestamp,
      );
      expect(runWithListSolution.toSolverResult().finalAnswer, {
        'solution': [1.0, 2.0, 3.0],
      });

      final runWithPrimitiveAnswer = HistoryRun(
        id: 'run-primitive-answer',
        method: 'integration/simpson-13',
        outputPayload: const {
          'finalAnswer': 3.14159,
        },
        createdAt: timestamp,
      );
      expect(runWithPrimitiveAnswer.toSolverResult().finalAnswer, {
        'value': 3.14159,
      });
    });

    test('preserves warnings from string or list formats', () {
      final runListWarnings = HistoryRun(
        id: 'run-list-warnings',
        method: 'ode/euler',
        outputPayload: const {
          'warnings': [
            'Step size h is too large',
            'Local truncation error high',
          ],
        },
        createdAt: timestamp,
      );
      expect(runListWarnings.toSolverResult().warnings, [
        'Step size h is too large',
        'Local truncation error high',
      ]);

      final runSingleWarning = HistoryRun(
        id: 'run-single-warning',
        method: 'ode/euler',
        outputPayload: const {
          'warnings': 'Matrix was poorly conditioned',
        },
        createdAt: timestamp,
      );
      expect(runSingleWarning.toSolverResult().warnings, [
        'Matrix was poorly conditioned',
      ]);
    });

    test(
      'preserves executionTimeMs from int, double, or String representations',
      () {
        final runInt = HistoryRun(
          id: 'run-int-time',
          method: 'test',
          outputPayload: const {'executionTimeMs': 120},
          createdAt: timestamp,
        );
        expect(runInt.toSolverResult().executionTimeMs, 120);

        final runDouble = HistoryRun(
          id: 'run-double-time',
          method: 'test',
          outputPayload: const {'executionTime': 85.7},
          createdAt: timestamp,
        );
        expect(runDouble.toSolverResult().executionTimeMs, 85);

        final runString = HistoryRun(
          id: 'run-string-time',
          method: 'test',
          outputPayload: const {'executionTimeMs': '250'},
          createdAt: timestamp,
        );
        expect(runString.toSolverResult().executionTimeMs, 250);
      },
    );

    test('preserves explanation from string in outputPayload', () {
      final run = HistoryRun(
        id: 'run-string-exp',
        method: 'test',
        outputPayload: const {
          'explanation': 'Newton method converged quadratically in 4 steps.',
        },
        createdAt: timestamp,
      );

      final result = run.toSolverResult();
      expect(
        result.explanation?.summary,
        'Newton method converged quadratically in 4 steps.',
      );
      expect(result.explanation?.steps, isEmpty);
    });

    test(
      'falls back to aiExplanations when explanation is omitted in outputPayload',
      () {
        final run = HistoryRun(
          id: 'run-ai-exp',
          method: 'test',
          aiExplanations: [
            HistoryExplanation(
              id: 'exp-ai-1',
              responseText: 'Pedagogical explanation generated by AI tutor.',
              createdAt: timestamp,
            ),
          ],
          createdAt: timestamp,
        );

        final result = run.toSolverResult();
        expect(
          result.explanation?.summary,
          'Pedagogical explanation generated by AI tutor.',
        );
      },
    );

    test('malformed or unexpected graphData does not crash conversion', () {
      final runMalformedGraph = HistoryRun(
        id: 'run-malformed-graph',
        method: 'test',
        outputPayload: const {
          'graphData': 'not-a-valid-graph-structure',
        },
        createdAt: timestamp,
      );

      final result = runMalformedGraph.toSolverResult();
      expect(result.graphData, 'not-a-valid-graph-structure');
    });

    test('empty outputPayload gracefully defaults all fields', () {
      final run = HistoryRun(
        id: 'run-empty',
        method: 'root/bisection',
        createdAt: timestamp,
      );

      final result = run.toSolverResult();
      expect(result.method, 'root/bisection');
      expect(result.status, isNull);
      expect(result.input, isEmpty);
      expect(result.iterations, isEmpty);
      expect(result.finalAnswer, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.executionTimeMs, 0);
      expect(result.explanation, isNull);
      expect(result.graphData, isNull);
      expect(result.requestId, 'run-empty');
      expect(result.timestamp, '2026-09-30T10:00:00.000Z');
    });
  });
}

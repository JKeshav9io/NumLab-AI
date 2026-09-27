import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_result_model.dart';

void main() {
  group('SolverExplanationModel', () {
    test('parses valid JSON map correctly', () {
      final json = {
        'summary': 'Bisection Method converged because tolerance reached.',
        'steps': [
          'Find a valid initial bracket [a, b].',
          'Compute midpoint c.',
        ],
      };

      final explanation = SolverExplanationModel.fromJson(json);

      expect(
        explanation.summary,
        'Bisection Method converged because tolerance reached.',
      );
      expect(explanation.steps.length, 2);
      expect(explanation.steps[0], 'Find a valid initial bracket [a, b].');
      expect(explanation.toJson(), json);
    });

    test('handles null and missing fields gracefully', () {
      final explanation = SolverExplanationModel.fromJson(const {});

      expect(explanation.summary, '');
      expect(explanation.steps, isEmpty);
    });

    test('two instances with same properties are equal', () {
      const e1 = SolverExplanationModel(
        summary: 'Converged',
        steps: ['step 1'],
      );
      const e2 = SolverExplanationModel(
        summary: 'Converged',
        steps: ['step 1'],
      );

      expect(e1, equals(e2));
    });
  });

  group('SolverResultModel', () {
    final sampleEnvelope = {
      'success': true,
      'data': {
        'method': 'Bisection Method',
        'status': 'converged',
        'input': {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
        },
        'iterations': [
          {
            'iteration': 1,
            'a': 1.0,
            'b': 2.0,
            'c': 1.5,
            'error': 0.5,
          },
        ],
        'finalAnswer': {
          'root': 1.5214,
          'functionValue': -0.00003,
          'iterationsUsed': 14,
          'converged': true,
          'reason': 'Tolerance reached',
        },
        'explanation': {
          'summary': 'Bisection converged.',
          'steps': ['Step 1', 'Step 2'],
        },
        'graphData': [
          {'x': 1.0, 'y': -2.0},
          {'x': 2.0, 'y': 4.0},
        ],
        'warnings': ['Warning 1'],
        'executionTimeMs': 12,
      },
      'meta': {
        'requestId': 'req-12345',
        'timestamp': '2026-09-27T04:47:21.000Z',
      },
    };

    test('parses full backend response envelope with meta', () {
      final result = SolverResultModel.fromJson(sampleEnvelope);

      expect(result.method, 'Bisection Method');
      expect(result.status, 'converged');
      expect(result.isConverged, isTrue);
      expect(result.root, 1.5214);
      expect(result.input['equation'], 'x^3 - x - 2');
      expect(result.iterations.length, 1);
      expect(result.finalAnswer['iterationsUsed'], 14);
      expect(result.explanation?.summary, 'Bisection converged.');
      expect(result.explanation?.steps.length, 2);
      expect(result.graphData, isA<List<dynamic>>());
      expect(result.warnings, ['Warning 1']);
      expect(result.executionTimeMs, 12);
      expect(result.requestId, 'req-12345');
      expect(result.timestamp, '2026-09-27T04:47:21.000Z');
    });

    test('parses direct data map without meta wrapper', () {
      final directData = sampleEnvelope['data']! as Map<String, dynamic>;
      final result = SolverResultModel.fromJson(directData);

      expect(result.method, 'Bisection Method');
      expect(result.root, 1.5214);
      expect(result.requestId, isNull);
      expect(result.timestamp, isNull);
    });

    test('linear system solution accessor works', () {
      final linearResult = SolverResultModel.fromJson(const {
        'method': 'Jacobi Method',
        'status': 'converged',
        'finalAnswer': {
          'solution': [1.0, 2.0],
          'converged': true,
        },
      });

      expect(linearResult.solutionVector, [1.0, 2.0]);
      expect(linearResult.isConverged, isTrue);
    });

    test('handles empty / minimal payload gracefully', () {
      final result = SolverResultModel.fromJson(const {});

      expect(result.method, '');
      expect(result.status, isNull);
      expect(result.input, isEmpty);
      expect(result.iterations, isEmpty);
      expect(result.finalAnswer, isEmpty);
      expect(result.explanation, isNull);
      expect(result.graphData, isNull);
      expect(result.warnings, isEmpty);
      expect(result.executionTimeMs, 0);
      expect(result.isConverged, isFalse);
    });

    test('toJson serializes correctly', () {
      final result = SolverResultModel.fromJson(sampleEnvelope);
      final json = result.toJson();

      expect(json['method'], 'Bisection Method');
      expect(json['status'], 'converged');
      expect(json['executionTimeMs'], 12);
      expect(
        (json['meta'] as Map<String, dynamic>?)?['requestId'],
        'req-12345',
      );
    });

    test('equality test compares props properly', () {
      final r1 = SolverResultModel.fromJson(sampleEnvelope);
      final r2 = SolverResultModel.fromJson(sampleEnvelope);

      expect(r1, equals(r2));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/history/data/models/ai_explanation_model.dart';
import 'package:numlab_frontend/features/history/data/models/history_run_model.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

void main() {
  group('HistoryRunModel', () {
    final validJson = <String, dynamic>{
      'id': 'run-123-uuid',
      'userId': 'user-456-uuid',
      'method': 'root/bisection',
      'inputPayload': <String, dynamic>{
        'equation': 'x^2 - 4',
        'lowerBound': 0,
        'upperBound': 3,
        'tolerance': 0.001,
      },
      'outputPayload': <String, dynamic>{
        'method': 'Bisection Method',
        'status': 'converged',
        'input': <String, dynamic>{'equation': 'x^2 - 4'},
        'iterations': <dynamic>[
          <String, dynamic>{'iteration': 1, 'c': 1.5},
        ],
        'finalAnswer': <String, dynamic>{'root': 2.0, 'converged': true},
        'warnings': <dynamic>[],
        'executionTimeMs': 2,
      },
      'createdAt': '2026-09-30T10:00:00.000Z',
      'aiExplanations': <dynamic>[
        <String, dynamic>{
          'id': 'exp-1',
          'responseText': 'Step 1 explanation',
          'createdAt': '2026-09-30T10:01:00.000Z',
        },
      ],
    };

    test('parses full backend history run JSON correctly', () {
      final model = HistoryRunModel.fromJson(validJson);

      expect(model.id, 'run-123-uuid');
      expect(model.userId, 'user-456-uuid');
      expect(model.method, 'root/bisection');
      expect(model.inputPayload['equation'], 'x^2 - 4');
      expect(model.outputPayload['method'], 'Bisection Method');
      expect(model.createdAt, DateTime.parse('2026-09-30T10:00:00.000Z'));
      expect(model.aiExplanations.length, 1);
      expect(model.aiExplanations.first.id, 'exp-1');
    });

    test('parses snake_case keys correctly', () {
      final snakeJson = <String, dynamic>{
        'id': 'run-snake',
        'user_id': 'user-snake',
        'method': 'linear/gauss-elimination',
        'input_payload': <String, dynamic>{
          'matrix': [
            [1, 2],
            [3, 4],
          ],
        },
        'output_payload': <String, dynamic>{'status': 'converged'},
        'created_at': '2026-09-30T12:00:00.000Z',
        'ai_explanations': <dynamic>[],
      };

      final model = HistoryRunModel.fromJson(snakeJson);

      expect(model.id, 'run-snake');
      expect(model.userId, 'user-snake');
      expect(model.method, 'linear/gauss-elimination');
      expect(model.inputPayload, isNotEmpty);
      expect(model.outputPayload['status'], 'converged');
      expect(model.aiExplanations, isEmpty);
    });

    test('handles missing optional fields with safe defaults', () {
      final minimalJson = <String, dynamic>{
        'id': 'run-minimal',
        'method': 'ode/euler',
      };

      final model = HistoryRunModel.fromJson(minimalJson);

      expect(model.id, 'run-minimal');
      expect(model.userId, isNull);
      expect(model.method, 'ode/euler');
      expect(model.inputPayload, isEmpty);
      expect(model.outputPayload, isEmpty);
      expect(model.aiExplanations, isEmpty);
      expect(model.createdAt, isNotNull);
    });

    test(
      'toSolverResult() maps outputPayload into functional SolverResult',
      () {
        final model = HistoryRunModel.fromJson(validJson);
        final solverResult = model.toSolverResult();

        expect(solverResult, isA<SolverResult>());
        expect(solverResult.method, 'Bisection Method');
        expect(solverResult.isConverged, isTrue);
        expect(solverResult.root, 2.0);
        expect(solverResult.executionTimeMs, 2);
        expect(solverResult.requestId, 'run-123-uuid');
        expect(solverResult.timestamp, '2026-09-30T10:00:00.000Z');
        expect(solverResult.hasIterations, isTrue);
      },
    );

    test(
      'toSolverResult() preserves input from inputPayload when missing in outputPayload',
      () {
        final model = HistoryRunModel(
          id: 'run-input-fallback',
          method: 'root/newton',
          createdAt: DateTime(2026, 9, 30),
          inputPayload: const <String, dynamic>{'equation': 'cos(x) - x'},
          outputPayload: const <String, dynamic>{
            'method': 'Newton-Raphson',
            'status': 'converged',
            'finalAnswer': <String, dynamic>{'root': 0.739085},
          },
        );

        final solverResult = model.toSolverResult();

        expect(solverResult.input['equation'], 'cos(x) - x');
        expect(solverResult.root, 0.739085);
      },
    );

    test('serializes to JSON map', () {
      final model = HistoryRunModel(
        id: 'run-json',
        userId: 'user-json',
        method: 'integration/trapezoidal',
        createdAt: DateTime.parse('2026-09-30T14:00:00.000Z'),
        inputPayload: const <String, dynamic>{'subintervals': 4},
        outputPayload: const <String, dynamic>{'status': 'converged'},
        aiExplanations: [
          AiExplanationModel(
            id: 'exp-json',
            responseText: 'Trapezoidal step',
            createdAt: DateTime.parse('2026-09-30T14:01:00.000Z'),
          ),
        ],
      );

      final json = model.toJson();

      expect(json['id'], 'run-json');
      expect(json['userId'], 'user-json');
      expect(json['method'], 'integration/trapezoidal');
      expect(json['createdAt'], '2026-09-30T14:00:00.000Z');
      expect(json['aiExplanations'], isA<List<dynamic>>());
      expect((json['aiExplanations'] as List).length, 1);
    });

    test('supports value equality via Equatable', () {
      final now = DateTime.now();
      final model1 = HistoryRunModel(
        id: 'run-1',
        method: 'root/bisection',
        createdAt: now,
      );
      final model2 = HistoryRunModel(
        id: 'run-1',
        method: 'root/bisection',
        createdAt: now,
      );
      final model3 = HistoryRunModel(
        id: 'run-2',
        method: 'root/bisection',
        createdAt: now,
      );

      expect(model1, equals(model2));
      expect(model1, isNot(equals(model3)));
    });
  });
}

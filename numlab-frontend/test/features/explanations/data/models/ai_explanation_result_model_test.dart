import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/explanations/data/models/ai_explanation_result_model.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/ai_explanation_result.dart';

void main() {
  group('AiExplanationResultModel', () {
    for (final tokens in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      test('ignores non-finite optional token metadata: $tokens', () {
        final model = AiExplanationResultModel.fromJson({
          'explanation': 'Valid explanation',
          'usage': {'total_tokens': tokens},
        });
        expect(model.explanation, 'Valid explanation');
        expect(model.totalTokens, isNull);
      });
    }

    for (final value in <Object?>[
      true,
      false,
      null,
      'true',
      'false',
      1,
      <Object?>[],
      <String, Object?>{},
    ]) {
      test('cache evidence is accepted only for a boolean: $value', () {
        final model = AiExplanationResultModel.fromJson({
          'explanation': 'Response',
          'model': 'cached',
          'cached': value,
        });
        expect(model.cacheStatus, value is bool ? value : isNull);
        expect(model.cached, value == true);
        expect(model.toEntity().cacheStatus, model.cacheStatus);
        expect(
          AiExplanationResultModel.fromEntity(model.toEntity()).cacheStatus,
          model.cacheStatus,
        );
      });
    }

    test('missing cache evidence stays unknown through serialization', () {
      final model = AiExplanationResultModel.fromJson(const {
        'explanation': 'Response',
        'model': 'cached',
        'usage': {'cached': true, 'total_tokens': 0},
      });
      expect(model.cached, isFalse);
      expect(model.cacheStatus, isNull);
      expect(model.toJson(), isNot(contains('cached')));
      expect(
        AiExplanationResultModel.fromJson(model.toJson()).cacheStatus,
        isNull,
      );
      expect(
        model.toEntity(),
        isNot(
          const AiExplanationResult(
            explanation: 'Response',
            model: 'cached',
            cached: false,
            totalTokens: 0,
          ),
        ),
      );
    });
    final completeEnvelope = {
      'success': true,
      'data': {
        'explanation': 'The calculation completed using 5 iterations.',
        'focus': 'steps',
        'model': 'gpt-4o-mini',
        'usage': {
          'total_tokens': 145,
          'prompt_tokens': 100,
          'completion_tokens': 45,
        },
        'cached': false,
        'source': {
          'method': 'Newton-Raphson',
          'status': 'converged',
        },
      },
      'meta': {
        'requestId': 'req-abc-789',
        'timestamp': '2026-10-15T22:05:00.000Z',
      },
    };

    final cachedEnvelope = {
      'success': true,
      'data': {
        'explanation': 'Cached explanation response text.',
        'focus': 'summary',
        'model': 'cached',
        'usage': {
          'total_tokens': 0,
          'cached': true,
        },
        'cached': true,
        'source': {
          'method': 'Secant Method',
          'status': 'converged',
        },
      },
      'meta': {
        'requestId': 'req-cache-111',
        'timestamp': '2026-10-15T22:06:00.000Z',
      },
    };

    test('parses successfully from standard backend response envelope', () {
      final model = AiExplanationResultModel.fromJson(completeEnvelope);

      expect(
        model.explanation,
        'The calculation completed using 5 iterations.',
      );
      expect(model.focus, 'steps');
      expect(model.model, 'gpt-4o-mini');
      expect(model.cached, isFalse);
      expect(model.method, 'Newton-Raphson');
      expect(model.status, 'converged');
      expect(model.totalTokens, 145);
      expect(model.requestId, 'req-abc-789');
      expect(model.timestamp, '2026-10-15T22:05:00.000Z');
    });

    test('parses successfully from inner data map directly', () {
      final dataMap = completeEnvelope['data']! as Map<String, dynamic>;
      final model = AiExplanationResultModel.fromJson(dataMap);

      expect(
        model.explanation,
        'The calculation completed using 5 iterations.',
      );
      expect(model.focus, 'steps');
      expect(model.model, 'gpt-4o-mini');
      expect(model.cached, isFalse);
      expect(model.method, 'Newton-Raphson');
      expect(model.status, 'converged');
      expect(model.totalTokens, 145);
    });

    test('parses cached explanation envelope correctly', () {
      final model = AiExplanationResultModel.fromJson(cachedEnvelope);

      expect(model.explanation, 'Cached explanation response text.');
      expect(model.focus, 'summary');
      expect(model.model, 'cached');
      expect(model.cached, isTrue);
      expect(model.totalTokens, 0);
      expect(model.method, 'Secant Method');
    });

    test('handles missing, null, or string-typed tokens gracefully', () {
      final sparseMap = <String, dynamic>{
        'explanation': 'Minimal explanation',
        'usage': {'total_tokens': '250'},
      };

      final model = AiExplanationResultModel.fromJson(sparseMap);

      expect(model.explanation, 'Minimal explanation');
      expect(model.focus, 'steps');
      expect(model.model, '');
      expect(model.cached, isFalse);
      expect(model.totalTokens, 250);
      expect(model.method, isNull);
      expect(model.status, isNull);
    });

    test('toEntity() converts to pure domain AiExplanationResult', () {
      final model = AiExplanationResultModel.fromJson(completeEnvelope);
      final entity = model.toEntity();

      expect(entity, isA<AiExplanationResult>());
      expect(entity.explanation, model.explanation);
      expect(entity.focus, model.focus);
      expect(entity.model, model.model);
      expect(entity.cached, model.cached);
      expect(entity.method, model.method);
      expect(entity.status, model.status);
      expect(entity.totalTokens, model.totalTokens);
      expect(entity.requestId, model.requestId);
      expect(entity.timestamp, model.timestamp);
    });

    test('fromEntity() constructs model preserving all entity fields', () {
      const entity = AiExplanationResult(
        explanation: 'Custom domain explanation',
        focus: 'warnings',
        model: 'gemini-1.5-pro',
        method: 'Gauss-Elimination',
        status: 'completed',
        totalTokens: 310,
        requestId: 'req-domain-99',
        timestamp: '2026-10-15T22:08:00.000Z',
      );

      final model = AiExplanationResultModel.fromEntity(entity);

      expect(model.explanation, entity.explanation);
      expect(model.focus, entity.focus);
      expect(model.model, entity.model);
      expect(model.cached, entity.cached);
      expect(model.method, entity.method);
      expect(model.status, entity.status);
      expect(model.totalTokens, entity.totalTokens);
      expect(model.requestId, entity.requestId);
      expect(model.timestamp, entity.timestamp);
    });

    test('toJson() produces serializable representation', () {
      final model = AiExplanationResultModel.fromJson(completeEnvelope);
      final json = model.toJson();

      expect(
        json['explanation'],
        'The calculation completed using 5 iterations.',
      );
      expect(json['focus'], 'steps');
      expect(json['model'], 'gpt-4o-mini');
      expect(json['cached'], isFalse);
      expect((json['source'] as Map)['method'], 'Newton-Raphson');
      expect((json['source'] as Map)['status'], 'converged');
      expect((json['usage'] as Map)['total_tokens'], 145);
      expect((json['meta'] as Map)['requestId'], 'req-abc-789');
    });
  });
}

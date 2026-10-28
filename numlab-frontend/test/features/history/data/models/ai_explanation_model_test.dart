import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/history/data/models/ai_explanation_model.dart';

void main() {
  group('AiExplanationModel', () {
    final validJson = <String, dynamic>{
      'id': 'exp-123-uuid',
      'solverRunId': 'run-456-uuid',
      'userId': 'user-789-uuid',
      'focusMode': 'steps',
      'promptHash': 'hash123abc',
      'responseText': '### Step-by-Step Analysis\n1. Initial step',
      'expiresAt': '2026-10-01T12:00:00.000Z',
      'createdAt': '2026-09-30T10:00:00.000Z',
    };

    test('parses full backend explanation JSON successfully', () {
      final model = AiExplanationModel.fromJson(validJson);

      expect(model.id, 'exp-123-uuid');
      expect(model.solverRunId, 'run-456-uuid');
      expect(model.userId, 'user-789-uuid');
      expect(model.focusMode, 'steps');
      expect(model.promptHash, 'hash123abc');
      expect(
        model.responseText,
        '### Step-by-Step Analysis\n1. Initial step',
      );
      expect(model.expiresAt, DateTime.parse('2026-10-01T12:00:00.000Z'));
      expect(model.createdAt, DateTime.parse('2026-09-30T10:00:00.000Z'));
    });

    test('parses snake_case keys from raw database outputs', () {
      final snakeJson = <String, dynamic>{
        'id': 'exp-snake',
        'solver_run_id': 'run-snake',
        'user_id': 'user-snake',
        'focus_mode': 'summary',
        'prompt_hash': 'hash-snake',
        'response_text': 'Summary text',
        'expires_at': '2026-10-02T12:00:00.000Z',
        'created_at': '2026-09-30T11:00:00.000Z',
      };

      final model = AiExplanationModel.fromJson(snakeJson);

      expect(model.id, 'exp-snake');
      expect(model.solverRunId, 'run-snake');
      expect(model.userId, 'user-snake');
      expect(model.focusMode, 'summary');
      expect(model.promptHash, 'hash-snake');
      expect(model.responseText, 'Summary text');
      expect(model.expiresAt, DateTime.parse('2026-10-02T12:00:00.000Z'));
      expect(model.createdAt, DateTime.parse('2026-09-30T11:00:00.000Z'));
    });

    test('handles nullable and omitted fields with safe fallbacks', () {
      final minimalJson = <String, dynamic>{
        'id': 'exp-minimal',
        'responseText': 'Simple response',
        'createdAt': '2026-09-30T10:00:00.000Z',
      };

      final model = AiExplanationModel.fromJson(minimalJson);

      expect(model.id, 'exp-minimal');
      expect(model.solverRunId, isNull);
      expect(model.userId, isNull);
      expect(model.focusMode, 'steps');
      expect(model.promptHash, isNull);
      expect(model.responseText, 'Simple response');
      expect(model.expiresAt, isNull);
    });

    test('serializes to JSON map matching expected transport shape', () {
      final model = AiExplanationModel(
        id: 'exp-to-json',
        solverRunId: 'run-to-json',
        userId: 'user-to-json',
        focusMode: 'warnings',
        promptHash: 'hash-xyz',
        responseText: 'Warning check',
        expiresAt: DateTime.parse('2026-10-05T00:00:00.000Z'),
        createdAt: DateTime.parse('2026-09-30T12:00:00.000Z'),
      );

      final json = model.toJson();

      expect(json['id'], 'exp-to-json');
      expect(json['solverRunId'], 'run-to-json');
      expect(json['userId'], 'user-to-json');
      expect(json['focusMode'], 'warnings');
      expect(json['promptHash'], 'hash-xyz');
      expect(json['responseText'], 'Warning check');
      expect(json['expiresAt'], '2026-10-05T00:00:00.000Z');
      expect(json['createdAt'], '2026-09-30T12:00:00.000Z');
    });

    test('supports value equality via Equatable', () {
      final now = DateTime.now();
      final model1 = AiExplanationModel(
        id: '1',
        responseText: 'Test',
        createdAt: now,
      );
      final model2 = AiExplanationModel(
        id: '1',
        responseText: 'Test',
        createdAt: now,
      );
      final model3 = AiExplanationModel(
        id: '2',
        responseText: 'Test',
        createdAt: now,
      );

      expect(model1, equals(model2));
      expect(model1, isNot(equals(model3)));
    });
  });
}

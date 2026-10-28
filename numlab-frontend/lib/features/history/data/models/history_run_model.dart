import 'package:numlab_frontend/features/history/data/models/ai_explanation_model.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_run.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_result_model.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

/// Data model representing a saved numerical calculation run in the user's history.
class HistoryRunModel extends HistoryRun {
  const HistoryRunModel({
    required super.id,
    required super.method,
    required super.createdAt,
    super.userId,
    super.inputPayload = const <String, dynamic>{},
    super.outputPayload = const <String, dynamic>{},
    super.aiExplanations = const <AiExplanationModel>[],
  });

  /// Parses [HistoryRunModel] from JSON map.
  factory HistoryRunModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parseMap(dynamic val) {
      if (val is Map<String, dynamic>) return val;
      if (val is Map) return Map<String, dynamic>.from(val);
      return const <String, dynamic>{};
    }

    final rawAi = json['aiExplanations'] ?? json['ai_explanations'];
    final explanations = rawAi is List
        ? rawAi
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (e) => AiExplanationModel.fromJson(
                  e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
                ),
              )
              .toList(growable: false)
        : const <AiExplanationModel>[];

    return HistoryRunModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString(),
      method: json['method']?.toString() ?? '',
      inputPayload: parseMap(json['inputPayload'] ?? json['input_payload']),
      outputPayload: parseMap(json['outputPayload'] ?? json['output_payload']),
      createdAt:
          DateTime.tryParse(
            json['createdAt']?.toString() ??
                json['created_at']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      aiExplanations: explanations,
    );
  }

  /// Constructs a [HistoryRunModel] from a domain [HistoryRun] entity.
  factory HistoryRunModel.fromEntity(HistoryRun entity) {
    return HistoryRunModel(
      id: entity.id,
      userId: entity.userId,
      method: entity.method,
      inputPayload: entity.inputPayload,
      outputPayload: entity.outputPayload,
      createdAt: entity.createdAt,
      aiExplanations: entity.aiExplanations
          .map(
            (e) =>
                e is AiExplanationModel ? e : AiExplanationModel.fromEntity(e),
          )
          .toList(growable: false),
    );
  }

  /// Converts this data model to a pure domain [HistoryRun] entity.
  HistoryRun toEntity() {
    return HistoryRun(
      id: id,
      userId: userId,
      method: method,
      inputPayload: inputPayload,
      outputPayload: outputPayload,
      createdAt: createdAt,
      aiExplanations: aiExplanations
          .map(
            (e) => e is AiExplanationModel ? e.toEntity() : e,
          )
          .toList(growable: false),
    );
  }

  /// Converts this historical record's output payload into a domain [SolverResult]
  /// for direct rendering in the result presentation view.
  @override
  SolverResult toSolverResult() {
    final payload = Map<String, dynamic>.from(outputPayload);
    if (!payload.containsKey('method') || payload['method'] == null) {
      payload['method'] = method;
    }
    if (!payload.containsKey('meta') && !payload.containsKey('requestId')) {
      payload['requestId'] = id;
    }
    if (!payload.containsKey('meta') && !payload.containsKey('timestamp')) {
      payload['timestamp'] = createdAt.toIso8601String();
    }
    if (!payload.containsKey('input') ||
        (payload['input'] is Map && (payload['input'] as Map).isEmpty)) {
      payload['input'] = inputPayload;
    }
    if (!payload.containsKey('finalAnswer') && !payload.containsKey('result')) {
      final rawAnswer = outputPayload['solution'];
      if (rawAnswer != null) {
        payload['finalAnswer'] = rawAnswer is Map<String, dynamic>
            ? rawAnswer
            : (rawAnswer is Map
                  ? Map<String, dynamic>.from(rawAnswer)
                  : {'solution': rawAnswer});
      }
    }
    if (!payload.containsKey('explanation') && aiExplanations.isNotEmpty) {
      payload['explanation'] = {
        'summary': aiExplanations.first.responseText,
        'steps': <dynamic>[],
      };
    }
    return SolverResultModel.fromJson(payload);
  }

  /// Serializes to JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      if (userId != null) 'userId': userId,
      'method': method,
      'inputPayload': inputPayload,
      'outputPayload': outputPayload,
      'createdAt': createdAt.toIso8601String(),
      if (aiExplanations.isNotEmpty)
        'aiExplanations': aiExplanations
            .map(
              (e) => e is AiExplanationModel ? e.toJson() : e.props,
            )
            .toList(),
    };
  }
}

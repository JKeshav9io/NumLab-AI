import 'package:numlab_frontend/features/explanations/domain/entities/ai_explanation_result.dart';

/// Data model representing the backend response for an AI explanation.
class AiExplanationResultModel extends AiExplanationResult {
  const AiExplanationResultModel({
    required super.explanation,
    super.focus = 'steps',
    super.model = '',
    super.cached,
    super.method,
    super.status,
    super.totalTokens,
    super.requestId,
    super.timestamp,
  });

  /// Factory parsing either the top-level envelope `{ success, data, meta }`
  /// or directly from the inner `data` map.
  factory AiExplanationResultModel.fromJson(Map<String, dynamic> json) {
    final data =
        json.containsKey('data') && json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json.containsKey('data') && json['data'] is Map
              ? Map<String, dynamic>.from(json['data'] as Map)
              : json);

    final meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : (data['meta'] is Map<String, dynamic>
              ? data['meta'] as Map<String, dynamic>
              : null);

    final requestId =
        (meta?['requestId'] ?? data['requestId'] ?? json['requestId'])
            ?.toString();
    final timestamp =
        (meta?['timestamp'] ?? data['timestamp'] ?? json['timestamp'])
            ?.toString();

    final source = data['source'] is Map ? data['source'] as Map : null;
    final method = source?['method']?.toString();
    final status = source?['status']?.toString();

    final usage = data['usage'] is Map ? data['usage'] as Map : null;
    int? totalTokens;
    if (usage != null) {
      final t = usage['total_tokens'] ?? usage['totalTokens'];
      if (t is num && t.isFinite) {
        totalTokens = t.toInt();
      } else if (t is String) {
        totalTokens = int.tryParse(t);
      }
    }

    final cachedVal = data['cached'];
    final cached = cachedVal is bool ? cachedVal : null;

    return AiExplanationResultModel(
      explanation: data['explanation']?.toString() ?? '',
      focus: data['focus']?.toString() ?? 'steps',
      model: data['model']?.toString() ?? '',
      cached: cached,
      method: method,
      status: status,
      totalTokens: totalTokens,
      requestId: requestId,
      timestamp: timestamp,
    );
  }

  /// Constructs an [AiExplanationResultModel] from domain entity.
  factory AiExplanationResultModel.fromEntity(AiExplanationResult entity) {
    return AiExplanationResultModel(
      explanation: entity.explanation,
      focus: entity.focus,
      model: entity.model,
      cached: entity.cacheStatus,
      method: entity.method,
      status: entity.status,
      totalTokens: entity.totalTokens,
      requestId: entity.requestId,
      timestamp: entity.timestamp,
    );
  }

  /// Converts this model to pure domain [AiExplanationResult].
  AiExplanationResult toEntity() => AiExplanationResult(
    explanation: explanation,
    focus: focus,
    model: model,
    cached: cacheStatus,
    method: method,
    status: status,
    totalTokens: totalTokens,
    requestId: requestId,
    timestamp: timestamp,
  );

  Map<String, dynamic> toJson() {
    return {
      'explanation': explanation,
      'focus': focus,
      'model': model,
      if (cacheStatus != null) 'cached': cacheStatus,
      if (method != null || status != null)
        'source': {
          if (method != null) 'method': method,
          if (status != null) 'status': status,
        },
      if (totalTokens != null)
        'usage': {
          'total_tokens': totalTokens,
        },
      if (requestId != null || timestamp != null)
        'meta': {
          if (requestId != null) 'requestId': requestId,
          if (timestamp != null) 'timestamp': timestamp,
        },
    };
  }
}

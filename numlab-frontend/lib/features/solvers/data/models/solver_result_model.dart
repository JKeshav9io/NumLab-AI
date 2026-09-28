import 'package:numlab_frontend/features/solvers/domain/entities/solver_explanation.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

/// Step-by-step mathematical explanation model included in solver responses.
class SolverExplanationModel extends SolverExplanation {
  const SolverExplanationModel({
    required super.summary,
    required super.steps,
  });

  /// Factory constructor parsing from backend JSON response.
  factory SolverExplanationModel.fromJson(Map<String, dynamic> json) {
    return SolverExplanationModel(
      summary: json['summary'] as String? ?? '',
      steps:
          (json['steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
    );
  }

  /// Constructs a [SolverExplanationModel] from a domain [SolverExplanation] entity.
  factory SolverExplanationModel.fromEntity(SolverExplanation entity) {
    return SolverExplanationModel(
      summary: entity.summary,
      steps: entity.steps,
    );
  }

  /// Converts this model to a pure domain [SolverExplanation] entity.
  SolverExplanation toEntity() => SolverExplanation(
    summary: summary,
    steps: steps,
  );

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'steps': steps,
    };
  }
}

/// Generic data model representing the backend execution response of any of the 27 numerical solvers.
class SolverResultModel extends SolverResult {
  const SolverResultModel({
    required super.method,
    required super.finalAnswer,
    super.status,
    super.input = const {},
    super.iterations = const [],
    super.explanation,
    super.graphData,
    super.warnings = const [],
    super.executionTimeMs = 0,
    super.requestId,
    super.timestamp,
  });

  /// Parses from either the complete response envelope `{ success, data, meta }`
  /// or directly from the inner `data` map.
  factory SolverResultModel.fromJson(Map<String, dynamic> json) {
    final data =
        json.containsKey('data') && json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final meta =
        (json['meta'] is Map<String, dynamic>
            ? json['meta'] as Map<String, dynamic>
            : null) ??
        (data['meta'] is Map<String, dynamic>
            ? data['meta'] as Map<String, dynamic>
            : null);

    final requestId =
        (meta?['requestId'] ?? data['requestId'] ?? json['requestId'])
            ?.toString();
    final timestamp =
        (meta?['timestamp'] ?? data['timestamp'] ?? json['timestamp'])
            ?.toString();

    SolverExplanationModel? explanation;
    if (data['explanation'] != null) {
      if (data['explanation'] is Map<String, dynamic>) {
        explanation = SolverExplanationModel.fromJson(
          data['explanation'] as Map<String, dynamic>,
        );
      } else if (data['explanation'] is String &&
          (data['explanation'] as String).isNotEmpty) {
        explanation = SolverExplanationModel(
          summary: data['explanation'] as String,
          steps: const [],
        );
      }
    }

    final rawWarnings = data['warnings'];
    var warnings = const <String>[];
    if (rawWarnings is List) {
      warnings = rawWarnings.map((e) => e.toString()).toList(growable: false);
    } else if (rawWarnings is String && rawWarnings.isNotEmpty) {
      warnings = [rawWarnings];
    }

    var executionTime = 0;
    final timeVal = data['executionTimeMs'] ?? data['executionTime'];
    if (timeVal is num) {
      executionTime = timeVal.toInt();
    } else if (timeVal is String) {
      executionTime =
          int.tryParse(timeVal) ?? (double.tryParse(timeVal)?.toInt() ?? 0);
    }

    var finalAnswer = const <String, dynamic>{};
    if (data['finalAnswer'] is Map<String, dynamic>) {
      finalAnswer = data['finalAnswer'] as Map<String, dynamic>;
    } else if (data['result'] is Map<String, dynamic>) {
      finalAnswer = data['result'] as Map<String, dynamic>;
    }

    return SolverResultModel(
      method: data['method'] as String? ?? '',
      status: data['status'] as String?,
      input: data['input'] is Map<String, dynamic>
          ? data['input'] as Map<String, dynamic>
          : const {},
      iterations: data['iterations'] is List
          ? (data['iterations'] as List<dynamic>)
          : const [],
      finalAnswer: finalAnswer,
      explanation: explanation,
      graphData: data['graphData'],
      warnings: warnings,
      executionTimeMs: executionTime,
      requestId: requestId,
      timestamp: timestamp,
    );
  }

  /// Constructs a [SolverResultModel] from a domain [SolverResult] entity.
  factory SolverResultModel.fromEntity(SolverResult entity) {
    return SolverResultModel(
      method: entity.method,
      status: entity.status,
      input: entity.input,
      iterations: entity.iterations,
      finalAnswer: entity.finalAnswer,
      explanation: entity.explanation != null
          ? (entity.explanation is SolverExplanationModel
                ? entity.explanation! as SolverExplanationModel
                : SolverExplanationModel.fromEntity(entity.explanation!))
          : null,
      graphData: entity.graphData,
      warnings: entity.warnings,
      executionTimeMs: entity.executionTimeMs,
      requestId: entity.requestId,
      timestamp: entity.timestamp,
    );
  }

  /// Converts this model to a pure domain [SolverResult] entity.
  SolverResult toEntity() => SolverResult(
    method: method,
    status: status,
    input: input,
    iterations: iterations,
    finalAnswer: finalAnswer,
    explanation: explanation != null
        ? (explanation is SolverExplanationModel
              ? (explanation! as SolverExplanationModel).toEntity()
              : explanation)
        : null,
    graphData: graphData,
    warnings: warnings,
    executionTimeMs: executionTimeMs,
    requestId: requestId,
    timestamp: timestamp,
  );

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      if (status != null) 'status': status,
      'input': input,
      'iterations': iterations,
      'finalAnswer': finalAnswer,
      if (explanation != null)
        'explanation': (explanation is SolverExplanationModel
            ? (explanation! as SolverExplanationModel).toJson()
            : SolverExplanationModel.fromEntity(explanation!).toJson()),
      if (graphData != null) 'graphData': graphData,
      'warnings': warnings,
      'executionTimeMs': executionTimeMs,
      if (requestId != null || timestamp != null)
        'meta': {
          if (requestId != null) 'requestId': requestId,
          if (timestamp != null) 'timestamp': timestamp,
        },
    };
  }
}

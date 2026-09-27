import 'package:equatable/equatable.dart';

/// Step-by-step mathematical explanation model included in solver responses.
class SolverExplanationModel extends Equatable {
  const SolverExplanationModel({
    required this.summary,
    required this.steps,
  });

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

  /// Summary explanation of the algorithm's outcome.
  final String summary;

  /// Ordered step-by-step mathematical reasoning steps.
  final List<String> steps;

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'steps': steps,
    };
  }

  @override
  List<Object?> get props => [summary, steps];
}

/// Generic data model representing the backend execution response of any of the 27 numerical solvers.
class SolverResultModel extends Equatable {
  const SolverResultModel({
    required this.method,
    required this.finalAnswer,
    this.status,
    this.input = const {},
    this.iterations = const [],
    this.explanation,
    this.graphData,
    this.warnings = const [],
    this.executionTimeMs = 0,
    this.requestId,
    this.timestamp,
  });

  /// Parses from either the complete response envelope `{ success, data, meta }`
  /// or directly from the inner `data` map.
  factory SolverResultModel.fromJson(Map<String, dynamic> json) {
    final data =
        json.containsKey('data') && json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final meta = json['meta'] as Map<String, dynamic>?;

    return SolverResultModel(
      method: data['method'] as String? ?? '',
      status: data['status'] as String?,
      input: data['input'] as Map<String, dynamic>? ?? const {},
      iterations: data['iterations'] is List
          ? (data['iterations'] as List<dynamic>)
          : const [],
      finalAnswer: data['finalAnswer'] as Map<String, dynamic>? ?? const {},
      explanation:
          data['explanation'] != null &&
              data['explanation'] is Map<String, dynamic>
          ? SolverExplanationModel.fromJson(
              data['explanation'] as Map<String, dynamic>,
            )
          : null,
      graphData: data['graphData'],
      warnings:
          (data['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      executionTimeMs: (data['executionTimeMs'] as num?)?.toInt() ?? 0,
      requestId: meta?['requestId'] as String?,
      timestamp: meta?['timestamp'] as String?,
    );
  }

  /// The method name returned by the solver service.
  final String method;

  /// Optional convergence or execution status (e.g. 'converged', 'diverged', 'max_iterations_reached').
  final String? status;

  /// Echo of the validated input parameters.
  final Map<String, dynamic> input;

  /// Detailed per-iteration tabular steps or intermediate calculations.
  final List<dynamic> iterations;

  /// Key mathematical results (e.g. root, solution vector, predicted value, error).
  final Map<String, dynamic> finalAnswer;

  /// Optional AI / algorithmic explanation steps.
  final SolverExplanationModel? explanation;

  /// Optional 2D curve and iteration point coordinates for plotting.
  final dynamic graphData;

  /// Non-fatal mathematical warnings (e.g. non-diagonally dominant matrix).
  final List<String> warnings;

  /// Wall-clock backend calculation time in milliseconds.
  final int executionTimeMs;

  /// Request ID extracted from response metadata.
  final String? requestId;

  /// Timestamp extracted from response metadata.
  final String? timestamp;

  /// Whether the solver converged to the specified tolerance.
  bool get isConverged =>
      (finalAnswer['converged'] as bool?) ?? (status == 'converged');

  /// Convenience accessor for single-variable root-finding solvers.
  num? get root => finalAnswer['root'] as num?;

  /// Convenience accessor for linear system solution vectors.
  List<dynamic>? get solutionVector =>
      finalAnswer['solution'] as List<dynamic>?;

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      if (status != null) 'status': status,
      'input': input,
      'iterations': iterations,
      'finalAnswer': finalAnswer,
      if (explanation != null) 'explanation': explanation!.toJson(),
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

  @override
  List<Object?> get props => [
    method,
    status,
    input,
    iterations,
    finalAnswer,
    explanation,
    graphData,
    warnings,
    executionTimeMs,
    requestId,
    timestamp,
  ];
}

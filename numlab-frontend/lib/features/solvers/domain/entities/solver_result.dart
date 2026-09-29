import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_explanation.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';

/// Generic domain entity representing the calculation result of a numerical solver execution.
///
/// Contains all numerical answers, intermediate calculation steps, convergence flags,
/// graph plotting data, non-fatal warnings, and execution metrics.
class SolverResult extends Equatable {
  const SolverResult({
    required this.method,
    required this.finalAnswer,
    this.status,
    this.input = const {},
    this.iterations = const [],
    this.explanation,
    this.graphData,
    this.typedGraphData,
    this.warnings = const [],
    this.executionTimeMs = 0,
    this.requestId,
    this.timestamp,
  });

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

  /// Optional algorithmic or AI explanation steps.
  final SolverExplanation? explanation;

  /// Optional 2D curve and iteration point coordinates for plotting.
  final dynamic graphData;

  /// Optional strongly-typed graph plotting data entity.
  final SolverGraphData? typedGraphData;

  /// Non-fatal mathematical warnings (e.g. non-diagonally dominant matrix).
  final List<String> warnings;

  /// Wall-clock backend calculation time in milliseconds.
  final int executionTimeMs;

  /// Request ID extracted from response metadata.
  final String? requestId;

  /// Timestamp extracted from response metadata.
  final String? timestamp;

  /// Helper to safely extract and parse a numeric value.
  static num? _parseNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val;
    if (val is String) return num.tryParse(val.trim());
    return null;
  }

  /// Helper to safely extract and parse an integer value.
  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val.trim());
    return null;
  }

  /// Whether the solver converged to the specified tolerance.
  bool get isConverged {
    final val = finalAnswer['converged'];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return status?.toLowerCase() == 'converged';
  }

  /// Convenience accessor for single-variable root-finding solvers.
  num? get root => _parseNum(finalAnswer['root']);

  /// Convenience accessor for linear system solution vectors.
  List<dynamic>? get solutionVector {
    final val = finalAnswer['solution'] ?? finalAnswer['solutionVector'];
    if (val is List) return val;
    return null;
  }

  /// Convenience accessor for numerical integration / differentiation / interpolation results.
  num? get resultValue => _parseNum(
    finalAnswer['result'] ??
        finalAnswer['integral'] ??
        finalAnswer['derivative'] ??
        finalAnswer['interpolatedValue'] ??
        finalAnswer['predictedY'] ??
        finalAnswer['estimatedDerivative'] ??
        finalAnswer['approximateDerivative'] ??
        finalAnswer['value'] ??
        finalAnswer['root'],
  );

  /// Convenience accessor for estimated or calculated error.
  num? get error => _parseNum(
    finalAnswer['error'] ??
        finalAnswer['estimatedError'] ??
        finalAnswer['approximateError'] ??
        finalAnswer['trueError'] ??
        finalAnswer['relativeError'] ??
        finalAnswer['absoluteError'],
  );

  /// Convenience accessor for total iterations count.
  int? get iterationsCount => _parseInt(
    finalAnswer['iterations'] ??
        finalAnswer['iterationsUsed'] ??
        finalAnswer['iterationCount'] ??
        finalAnswer['totalIterations'] ??
        (iterations.isNotEmpty ? iterations.length : null),
  );

  /// Whether the result contains graphable data.
  bool get hasGraphData =>
      (typedGraphData != null && typedGraphData!.isNotEmpty) ||
      (graphData != null &&
          (graphData is! List || (graphData as List).isNotEmpty) &&
          (graphData is! Map || (graphData as Map).isNotEmpty));

  /// Whether the result contains an explanation.
  bool get hasExplanation =>
      explanation != null &&
      (explanation!.summary.isNotEmpty || explanation!.steps.isNotEmpty);

  /// Whether the result contains non-fatal warnings.
  bool get hasWarnings => warnings.isNotEmpty;

  /// Whether the result contains iteration steps.
  bool get hasIterations => iterations.isNotEmpty;

  @override
  List<Object?> get props => [
    method,
    status,
    input,
    iterations,
    finalAnswer,
    explanation,
    graphData,
    typedGraphData,
    warnings,
    executionTimeMs,
    requestId,
    timestamp,
  ];
}

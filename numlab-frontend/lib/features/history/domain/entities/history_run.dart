import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/features/history/domain/entities/history_explanation.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_explanation.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

/// Domain entity representing a historical numerical computation execution.
class HistoryRun extends Equatable {
  const HistoryRun({
    required this.id,
    required this.method,
    required this.createdAt,
    this.userId,
    this.inputPayload = const <String, dynamic>{},
    this.outputPayload = const <String, dynamic>{},
    this.aiExplanations = const <HistoryExplanation>[],
  });

  /// Unique UUID of the calculation run.
  final String id;

  /// Owner user UUID, or null for anonymous runs.
  final String? userId;

  /// Method route key (e.g. 'root/bisection', 'interpolation/lagrange').
  final String method;

  /// Input parameters supplied by the student at execution time.
  final Map<String, dynamic> inputPayload;

  /// Structured calculation outputs returned by the backend solver.
  final Map<String, dynamic> outputPayload;

  /// Execution timestamp.
  final DateTime createdAt;

  /// Attached AI pedagogical explanations.
  final List<HistoryExplanation> aiExplanations;

  /// Converts this historical record's output payload into a domain [SolverResult]
  /// for presentation in solver result views.
  SolverResult toSolverResult() {
    final methodStr = outputPayload['method'] as String? ?? method;
    final statusStr = outputPayload['status'] as String?;

    final rawInput = outputPayload['input'];
    final inputMap = rawInput is Map<String, dynamic> && rawInput.isNotEmpty
        ? rawInput
        : (rawInput is Map && rawInput.isNotEmpty
              ? Map<String, dynamic>.from(rawInput)
              : inputPayload);

    final iterationsList = outputPayload['iterations'] is List
        ? (outputPayload['iterations'] as List<dynamic>)
        : const <dynamic>[];

    var finalAnswerMap = const <String, dynamic>{};
    final rawAnswer =
        outputPayload['finalAnswer'] ??
        outputPayload['result'] ??
        outputPayload['solution'];
    if (rawAnswer is Map<String, dynamic>) {
      finalAnswerMap = rawAnswer;
    } else if (rawAnswer is Map) {
      finalAnswerMap = Map<String, dynamic>.from(rawAnswer);
    } else if (rawAnswer is List) {
      finalAnswerMap = {'solution': rawAnswer};
    } else if (rawAnswer != null) {
      finalAnswerMap = {'value': rawAnswer};
    }

    final rawWarnings = outputPayload['warnings'];
    var warningsList = const <String>[];
    if (rawWarnings is List) {
      warningsList = rawWarnings
          .map((e) => e.toString())
          .toList(growable: false);
    } else if (rawWarnings is String && rawWarnings.isNotEmpty) {
      warningsList = [rawWarnings];
    }

    var executionTime = 0;
    final timeVal =
        outputPayload['executionTimeMs'] ?? outputPayload['executionTime'];
    if (timeVal is num) {
      executionTime = timeVal.toInt();
    } else if (timeVal is String) {
      executionTime = int.tryParse(timeVal) ?? 0;
    }

    SolverExplanation? explanationEntity;
    final expVal = outputPayload['explanation'];
    if (expVal is Map) {
      explanationEntity = SolverExplanation(
        summary: expVal['summary']?.toString() ?? '',
        steps:
            (expVal['steps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const [],
      );
    } else if (expVal is String && expVal.isNotEmpty) {
      explanationEntity = SolverExplanation(summary: expVal, steps: const []);
    } else if (aiExplanations.isNotEmpty) {
      explanationEntity = SolverExplanation(
        summary: aiExplanations.first.responseText,
        steps: const [],
      );
    }

    final rawGraphData = outputPayload['graphData'];

    return SolverResult(
      method: methodStr,
      status: statusStr,
      input: inputMap,
      iterations: iterationsList,
      finalAnswer: finalAnswerMap,
      explanation: explanationEntity,
      graphData: rawGraphData,
      warnings: warningsList,
      executionTimeMs: executionTime,
      requestId: id,
      timestamp: createdAt.toIso8601String(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    method,
    inputPayload,
    outputPayload,
    createdAt,
    aiExplanations,
  ];
}

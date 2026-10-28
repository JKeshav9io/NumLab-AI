import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/ai_explanation_result.dart';
import 'package:numlab_frontend/features/explanations/domain/repositories/explanation_repository.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

/// Primary domain use case for requesting pedagogical AI explanations of completed calculations.
///
/// Ensures clean architecture boundary:
/// - Validates solver result readiness (non-empty method, non-empty final answer, iteration bounds).
/// - Validates focus mode against supported backend values ('summary', 'steps', 'warnings', 'lab-report').
/// - Prevents re-executing solvers or generating explanations locally.
/// - Returns [Either<Failure, AiExplanationResult>].
class ExplainUseCase {
  const ExplainUseCase(this._repository);

  final ExplanationRepository _repository;

  /// Supported focus modes aligned with backend `FOCUS_VALUES`.
  static const List<String> supportedFocusModes = [
    'summary',
    'steps',
    'warnings',
    'lab-report',
  ];

  /// Maximum allowed iterations for explanation payload (mirrors backend `MAX_EXPLAIN_ITERATIONS = 200`).
  static const int maxExplainIterations = 200;

  /// Maximum allowed warnings for explanation payload (mirrors backend `MAX_EXPLAIN_WARNINGS = 50`).
  static const int maxExplainWarnings = 50;

  /// Maximum allowed graph points per array (mirrors backend `MAX_GRAPH_ARRAY_POINTS = 500`).
  static const int maxGraphArrayPoints = 500;

  /// Requests an explanation for [solverResult].
  Future<Either<Failure, AiExplanationResult>> call({
    required SolverResult solverResult,
    String? focus,
    bool? includeGraphSummary,
  }) async {
    // 1. Validate solver result method
    if (solverResult.method.trim().isEmpty) {
      return const Left(
        ValidationFailure(
          message: 'Solver result must have a valid method name',
          fieldErrors: [
            FieldError(field: 'method', message: 'Method cannot be empty'),
          ],
        ),
      );
    }

    // 2. Validate solver result final answer
    if (solverResult.finalAnswer.isEmpty) {
      return const Left(
        ValidationFailure(
          message: 'Solver result must have a non-empty final answer',
          fieldErrors: [
            FieldError(
              field: 'finalAnswer',
              message: 'Final answer cannot be empty',
            ),
          ],
        ),
      );
    }

    // 3. Validate focus mode if provided
    final normalizedFocus = focus?.trim().toLowerCase();
    if (normalizedFocus != null &&
        normalizedFocus.isNotEmpty &&
        !supportedFocusModes.contains(normalizedFocus)) {
      return Left(
        ValidationFailure(
          message: 'Invalid explanation focus: "$focus"',
          fieldErrors: [
            FieldError(
              field: 'focus',
              message: 'Must be one of: ${supportedFocusModes.join(', ')}',
            ),
          ],
        ),
      );
    }

    // 4. Validate iterations limit
    if (solverResult.iterations.length > maxExplainIterations) {
      return const Left(
        ValidationFailure(
          message:
              'iterations contains too many items for AI explanation; max $maxExplainIterations iterations allowed',
          fieldErrors: [
            FieldError(
              field: 'iterations',
              message: 'Max $maxExplainIterations iterations allowed',
            ),
          ],
        ),
      );
    }

    // 5. Validate warnings limit
    if (solverResult.warnings.length > maxExplainWarnings) {
      return const Left(
        ValidationFailure(
          message:
              'warnings contains too many items for AI explanation; max $maxExplainWarnings warnings allowed',
          fieldErrors: [
            FieldError(
              field: 'warnings',
              message: 'Max $maxExplainWarnings warnings allowed',
            ),
          ],
        ),
      );
    }

    // 6. Validate graph data size
    final graph = solverResult.graphData;
    if (graph is List && graph.length > maxGraphArrayPoints) {
      return const Left(
        ValidationFailure(
          message:
              'graphData contains too many points for AI explanation; max $maxGraphArrayPoints points per graph array',
          fieldErrors: [
            FieldError(
              field: 'graphData',
              message: 'Max $maxGraphArrayPoints points allowed',
            ),
          ],
        ),
      );
    }
    if (graph is Map) {
      for (final entry in graph.entries) {
        if (entry.value is List &&
            (entry.value as List).length > maxGraphArrayPoints) {
          return const Left(
            ValidationFailure(
              message:
                  'graphData contains too many points for AI explanation; max $maxGraphArrayPoints points per graph array',
              fieldErrors: [
                FieldError(
                  field: 'graphData',
                  message: 'Max $maxGraphArrayPoints points allowed',
                ),
              ],
            ),
          );
        }
      }
    }

    // 7. Forward to repository
    return _repository.explain(
      solverResult: solverResult,
      focus: normalizedFocus,
      includeGraphSummary: includeGraphSummary,
    );
  }
}

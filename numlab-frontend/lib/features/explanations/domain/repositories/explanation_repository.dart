import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/ai_explanation_result.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

/// Contract for AI explanation repository operations.
// ignore: one_member_abstracts
abstract interface class ExplanationRepository {
  /// Requests an AI pedagogical explanation for an already computed [solverResult].
  ///
  /// [focus] specifies pedagogical angle: 'summary', 'steps', 'warnings', 'lab-report'.
  /// [includeGraphSummary] indicates if graphical data trends should be summarized.
  Future<Either<Failure, AiExplanationResult>> explain({
    required SolverResult solverResult,
    String? focus,
    bool? includeGraphSummary,
  });
}

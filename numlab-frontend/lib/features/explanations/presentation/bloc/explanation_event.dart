import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/entities.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

/// Sealed hierarchy of all explanation events handled by `ExplanationBloc`.
sealed class ExplanationEvent extends Equatable {
  const ExplanationEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to request an AI pedagogical explanation for a completed [solverResult].
final class ExplanationRequested extends ExplanationEvent {
  const ExplanationRequested({
    required this.solverResult,
    this.focus,
    this.includeGraphSummary,
  });

  /// The completed calculation result to explain.
  final SolverResult solverResult;

  /// Pedagogical focus mode ('summary', 'steps', 'warnings', 'lab-report').
  final String? focus;

  /// Whether graphical trend summary should be requested.
  final bool? includeGraphSummary;

  @override
  List<Object?> get props => [solverResult, focus, includeGraphSummary];
}

/// Dispatched to preload or inject an already-available explanation entity.
final class ExplanationPreloaded extends ExplanationEvent {
  const ExplanationPreloaded(this.explanation);

  /// Pre-existing explanation to populate into state.
  final AiExplanationResult explanation;

  @override
  List<Object?> get props => [explanation];
}

/// Dispatched to reset the explanation state back to initial state.
final class ExplanationReset extends ExplanationEvent {
  const ExplanationReset();
}

/// Internal loading notification for one request; never starts a network call.
final class ExplanationWaitElapsed extends ExplanationEvent {
  const ExplanationWaitElapsed(this.requestVersion);

  final int requestVersion;

  @override
  List<Object?> get props => [requestVersion];
}

import 'package:equatable/equatable.dart';

/// Step-by-step mathematical explanation included in solver responses.
class SolverExplanation extends Equatable {
  const SolverExplanation({
    required this.summary,
    required this.steps,
  });

  /// Summary explanation of the algorithm's outcome.
  final String summary;

  /// Ordered step-by-step mathematical reasoning steps.
  final List<String> steps;

  @override
  List<Object?> get props => [summary, steps];
}

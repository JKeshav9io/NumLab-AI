import 'package:equatable/equatable.dart';

/// Rule for validating interdependent constraints between multiple fields
/// (e.g. lowerBound < upperBound, matrix row length == column length, either xn or steps).
class SolverCrossFieldRule extends Equatable {
  const SolverCrossFieldRule({
    required this.id,
    required this.description,
    required this.affectedFieldNames,
    required this.validator,
  });

  /// Unique identifier matching backend validation rule name
  /// (e.g. 'bounds.ordered', 'guesses.distinct').
  final String id;

  /// Human-readable explanation of the validation requirement.
  final String description;

  /// Field names involved in this cross-field check.
  final List<String> affectedFieldNames;

  /// Function that executes the cross-field validation on the form values map.
  /// Returns an error message if invalid, or null if valid.
  final String? Function(Map<String, dynamic> formValues) validator;

  /// Executes the validation rule against [formValues].
  String? validate(Map<String, dynamic> formValues) {
    return validator(formValues);
  }

  @override
  List<Object?> get props => [id, description, affectedFieldNames];
}

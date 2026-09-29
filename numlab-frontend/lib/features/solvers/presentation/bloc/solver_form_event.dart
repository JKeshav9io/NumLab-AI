import 'package:equatable/equatable.dart';

/// Sealed hierarchy of all events handled by the solver form BLoC.
sealed class SolverFormEvent extends Equatable {
  const SolverFormEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to initialize and load the configuration for a specific solver.
final class SolverFormLoadStarted extends SolverFormEvent {
  const SolverFormLoadStarted({
    required this.solverId,
    this.initialValues,
  });

  /// The unique solver identifier or API endpoint.
  final String solverId;

  /// Optional pre-filled parameter values (e.g. from history or deep link).
  final Map<String, dynamic>? initialValues;

  @override
  List<Object?> get props => [solverId, initialValues];
}

/// Dispatched whenever a single input field value changes in the dynamic solver form.
final class SolverFormFieldChanged extends SolverFormEvent {
  const SolverFormFieldChanged({
    required this.fieldName,
    required this.value,
  });

  /// The parameter identifier matching the solver field schema name.
  final String fieldName;

  /// The new raw or parsed input value.
  final dynamic value;

  @override
  List<Object?> get props => [fieldName, value];
}

/// Dispatched when multiple input fields are updated simultaneously.
final class SolverFormFieldsBulkChanged extends SolverFormEvent {
  const SolverFormFieldsBulkChanged(this.values);

  /// Key-value pairs of updated form fields.
  final Map<String, dynamic> values;

  @override
  List<Object?> get props => [values];
}

/// Dispatched to validate the current form values against field and cross-field rules.
final class SolverFormValidateRequested extends SolverFormEvent {
  const SolverFormValidateRequested();
}

/// Dispatched to reset the form inputs back to default schema values.
final class SolverFormResetRequested extends SolverFormEvent {
  const SolverFormResetRequested();
}

/// Dispatched to submit the form and trigger numerical solver execution.
final class SolverFormSubmitted extends SolverFormEvent {
  const SolverFormSubmitted({this.accessToken});

  /// Optional auth token override for user history attribution.
  final String? accessToken;

  @override
  List<Object?> get props => [accessToken];
}

/// Dispatched to clear any existing calculation result.
final class SolverFormClearResultRequested extends SolverFormEvent {
  const SolverFormClearResultRequested();
}

/// Dispatched to switch the active solver method within a category workspace.
final class SolverFormMethodSwitched extends SolverFormEvent {
  const SolverFormMethodSwitched({
    required this.solverId,
  });

  /// The unique solver identifier of the target method.
  final String solverId;

  @override
  List<Object?> get props => [solverId];
}

import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_field_validation.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_input_field_type.dart';

/// Option item for select / dropdown fields.
class SolverSelectOption extends Equatable {
  const SolverSelectOption({
    required this.label,
    required this.value,
  });

  /// The human-readable option label.
  final String label;

  /// The actual value passed in API payload.
  final String value;

  @override
  List<Object?> get props => [label, value];
}

/// Metadata configuration for a single input field within a solver form.
class SolverInputFieldConfig extends Equatable {
  const SolverInputFieldConfig({
    required this.name,
    required this.label,
    required this.type,
    this.defaultValue,
    this.placeholder,
    this.helperText,
    this.validation = const SolverFieldValidation(),
    this.options,
  });

  /// The parameter key expected by the backend in the request body.
  final String name;

  /// The user-facing label for the form field.
  final String label;

  /// The input control type (e.g. equation, number, select, matrix).
  final SolverInputFieldType type;

  /// Default value pre-populated in the form.
  final dynamic defaultValue;

  /// Placeholder text shown inside empty input fields.
  final String? placeholder;

  /// Helper / tooltip text explaining the parameter's mathematical role.
  final String? helperText;

  /// Validation rules and constraints applied to this field.
  final SolverFieldValidation validation;

  /// Predefined selectable choices when [type] is [SolverInputFieldType.select].
  final List<SolverSelectOption>? options;

  /// Validates a given [value] using this field's validation rules.
  String? validate(dynamic value) {
    return validation.validate(value, fieldLabel: label);
  }

  @override
  List<Object?> get props => [
    name,
    label,
    type,
    defaultValue,
    placeholder,
    helperText,
    validation,
    options,
  ];
}

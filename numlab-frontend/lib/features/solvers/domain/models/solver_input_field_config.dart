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

  /// Validates a given [value] using this field's validation rules and type constraints.
  String? validate(dynamic value) {
    if (validation.isRequired) {
      if (value == null) {
        return '$label is required';
      }
      if (value is String && value.trim().isEmpty) {
        return '$label is required';
      }
      if (value is Iterable && value.isEmpty) {
        return '$label is required';
      }
    } else if (value == null || (value is String && value.trim().isEmpty)) {
      // Optional field with no value is valid
      return null;
    }

    switch (type) {
      case SolverInputFieldType.number:
        num? numericVal;
        if (value is num) {
          numericVal = value;
        } else if (value is String) {
          numericVal = num.tryParse(value.trim());
          if (numericVal == null) {
            return '$label must be a valid number';
          }
        } else {
          return '$label must be a valid number';
        }
        return validation.validate(numericVal, fieldLabel: label);

      case SolverInputFieldType.integer:
        int? intVal;
        if (value is int) {
          intVal = value;
        } else if (value is num) {
          if (value % 1 == 0) {
            intVal = value.toInt();
          } else {
            return '$label must be a valid integer';
          }
        } else if (value is String) {
          intVal = int.tryParse(value.trim());
          if (intVal == null) {
            return '$label must be a valid integer';
          }
        } else {
          return '$label must be a valid integer';
        }
        return validation.validate(intVal, fieldLabel: label);

      case SolverInputFieldType.vector:
        if (value is! List) {
          return '$label must be a valid numeric vector';
        }
        for (final item in value) {
          if (item is! num &&
              (item is! String || num.tryParse(item.trim()) == null)) {
            return '$label elements must be valid numbers';
          }
        }
        return validation.validate(value, fieldLabel: label);

      case SolverInputFieldType.matrix:
        if (value is! List) {
          return '$label must be a valid numeric matrix';
        }
        if (value.isNotEmpty) {
          int? expectedCols;
          for (final row in value) {
            if (row is! List) {
              return '$label rows must be lists';
            }
            if (expectedCols == null) {
              expectedCols = row.length;
            } else if (row.length != expectedCols) {
              return '$label rows must all have the same length ($expectedCols)';
            }
            for (final cell in row) {
              if (cell is! num &&
                  (cell is! String || num.tryParse(cell.trim()) == null)) {
                return '$label matrix cells must be valid numbers';
              }
            }
          }
        }
        return validation.validate(value, fieldLabel: label);

      case SolverInputFieldType.pointList:
        if (value is! List) {
          return '$label must be a valid list of coordinates';
        }
        for (final pt in value) {
          if (pt is! Map) {
            return '$label items must be point objects with x and y coordinates';
          }
          final rawX = pt['x'];
          final rawY = pt['y'];
          if (rawX == null ||
              (rawX is! num &&
                  (rawX is! String || num.tryParse(rawX.trim()) == null))) {
            return '$label points must contain valid numeric x coordinates';
          }
          if (rawY == null ||
              (rawY is! num &&
                  (rawY is! String || num.tryParse(rawY.trim()) == null))) {
            return '$label points must contain valid numeric y coordinates';
          }
        }
        return validation.validate(value, fieldLabel: label);

      case SolverInputFieldType.equation:
      case SolverInputFieldType.boolean:
      case SolverInputFieldType.select:
        return validation.validate(value, fieldLabel: label);
    }
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

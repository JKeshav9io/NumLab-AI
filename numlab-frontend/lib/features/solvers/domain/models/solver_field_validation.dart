import 'package:equatable/equatable.dart';

/// Validation constraints and rules for a solver input field,
/// directly mirroring backend Joi validation schemas.
class SolverFieldValidation extends Equatable {
  const SolverFieldValidation({
    this.isRequired = true,
    this.minValue,
    this.maxValue,
    this.isPositive = false,
    this.maxLength,
    this.minItems,
    this.maxItems,
    this.allowedValues,
    this.mustBeEven = false,
    this.mustBeDivisibleBy,
    this.customValidator,
  });

  /// Whether the field is mandatory.
  final bool isRequired;

  /// Minimum numeric value (inclusive).
  final num? minValue;

  /// Maximum numeric value (inclusive).
  final num? maxValue;

  /// Whether the numeric value must be strictly positive (> 0).
  final bool isPositive;

  /// Maximum character length for strings (e.g. 500 for equations).
  final int? maxLength;

  /// Minimum number of elements (for vectors, matrices, or points).
  final int? minItems;

  /// Maximum number of elements (for vectors, matrices, or points).
  final int? maxItems;

  /// List of allowed discrete values (for dropdowns or fixed sets).
  final List<dynamic>? allowedValues;

  /// Whether integer value must be even (e.g. Simpson's 1/3 rule).
  final bool mustBeEven;

  /// Integer divisor required (e.g. 3 for Simpson's 3/8 rule).
  final int? mustBeDivisibleBy;

  /// Optional custom validator function for advanced field-level checks.
  final String? Function(dynamic value)? customValidator;

  /// Validates a [value] against these rules. Returns error message if invalid, or null if valid.
  String? validate(dynamic value, {String? fieldLabel}) {
    final label = fieldLabel ?? 'Field';

    if (isRequired) {
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

    if (value is String) {
      final trimmed = value.trim();
      if (maxLength != null && trimmed.length > maxLength!) {
        return '$label must not exceed $maxLength characters';
      }
    }

    if (value is num) {
      if (isPositive && value <= 0) {
        return '$label must be positive';
      }
      if (minValue != null && value < minValue!) {
        return '$label must be at least $minValue';
      }
      if (maxValue != null && value > maxValue!) {
        return '$label must not exceed $maxValue';
      }
      if (mustBeEven && value.toInt() % 2 != 0) {
        return '$label must be an even number';
      }
      if (mustBeDivisibleBy != null &&
          value.toInt() % mustBeDivisibleBy! != 0) {
        return '$label must be divisible by $mustBeDivisibleBy';
      }
    }

    if (value is List) {
      if (minItems != null && value.length < minItems!) {
        return '$label requires at least $minItems items';
      }
      if (maxItems != null && value.length > maxItems!) {
        return '$label must not exceed $maxItems items';
      }
    }

    if (allowedValues != null && !allowedValues!.contains(value)) {
      return '$label must be one of: ${allowedValues!.join(", ")}';
    }

    if (customValidator != null) {
      return customValidator!(value);
    }

    return null;
  }

  @override
  List<Object?> get props => [
    isRequired,
    minValue,
    maxValue,
    isPositive,
    maxLength,
    minItems,
    maxItems,
    allowedValues,
    mustBeEven,
    mustBeDivisibleBy,
  ];
}

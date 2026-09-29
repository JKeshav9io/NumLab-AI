import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_category.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_cross_field_rule.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_input_field_config.dart';

/// Complete configuration and contract descriptor for a numerical solver.
///
/// Contains all parameter metadata, endpoints, default values,
/// and validation rules matching backend Joi validators.
class SolverMethodConfig extends Equatable {
  const SolverMethodConfig({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.endpoint,
    required this.fields,
    this.crossFieldRules = const [],
    this.supportsGraph = true,
    this.supportsExplanation = true,
  });

  /// Unique slug identifier for the method (e.g. 'bisection', 'jacobi', 'lagrange').
  final String id;

  /// Human-readable display name (e.g. 'Bisection Method', 'Jacobi Method').
  final String name;

  /// Mathematical domain category.
  final SolverCategory category;

  /// Brief description of the solver's purpose and algorithm.
  final String description;

  /// API endpoint path relative to baseUrl (e.g. '/solve/root/bisection').
  final String endpoint;

  /// Ordered list of input field descriptors for rendering the dynamic solver form.
  final List<SolverInputFieldConfig> fields;

  /// Cross-field relational validation rules (e.g. lowerBound < upperBound).
  final List<SolverCrossFieldRule> crossFieldRules;

  /// Whether this solver returns plot data / has includeGraphData support.
  final bool supportsGraph;

  /// Whether this solver supports AI step-by-step explanations.
  final bool supportsExplanation;

  /// Finds an input field config by its parameter [name].
  SolverInputFieldConfig? getField(String name) {
    for (final field in fields) {
      if (field.name == name) {
        return field;
      }
    }
    return null;
  }

  /// Builds a map of default values for all fields in this solver.
  Map<String, dynamic> defaultPayload() {
    final payload = <String, dynamic>{};
    for (final field in fields) {
      if (field.defaultValue != null) {
        payload[field.name] = field.defaultValue;
      }
    }
    return payload;
  }

  /// Validates a [payload] map against both field-level rules and cross-field rules.
  ///
  /// Returns a map of `{fieldNameOrRuleId: errorMessage}`.
  /// If the map is empty, the payload is completely valid.
  Map<String, String> validate(Map<String, dynamic> payload) {
    final errors = <String, String>{};

    // 1. Field-level validation
    for (final field in fields) {
      final value = payload[field.name];
      final error = field.validate(value);
      if (error != null) {
        errors[field.name] = error;
      }
    }

    // 2. Cross-field validation (only run if affected fields don't already have syntax errors)
    for (final rule in crossFieldRules) {
      final error = rule.validate(payload);
      if (error != null) {
        errors[rule.id] = error;
      }
    }

    return errors;
  }

  static final RegExp _functionNamePattern = RegExp(
    r'\b(sin|cos|tan|cot|sec|csc|asin|acos|atan|acot|asec|acsc|sinh|cosh|tanh|coth|sech|csch|asinh|acosh|atanh|exp|log|ln|sqrt|cbrt|abs)\b',
    caseSensitive: false,
  );

  /// Normalizes supported standard mathematical function names (e.g. `Sin` -> `sin`, `COS` -> `cos`, `Exp` -> `exp`)
  /// without altering user variable names or arbitrary algebraic expressions.
  static String normalizeExpression(String expr) {
    return expr.replaceAllMapped(
      _functionNamePattern,
      (match) => match[0]!.toLowerCase(),
    );
  }

  /// Sanitizes a [rawPayload] map before network serialization:
  /// - Omits any keys with `null` values or empty/whitespace strings.
  /// - Normalizes standard function names in equation fields (e.g. `Sin(x)` -> `sin(x)`).
  /// - For ODE methods, ensures either `xn` or `steps` is sent according to configured input, not both.
  /// - Preserves valid non-null values (e.g. booleans, numbers, matrices, point lists) unchanged.
  static Map<String, dynamic> sanitizePayload(Map<String, dynamic> rawPayload) {
    final sanitized = <String, dynamic>{};

    for (final entry in rawPayload.entries) {
      final key = entry.key;
      var value = entry.value;

      if (value == null) {
        continue;
      }
      if (value is String) {
        if (value.trim().isEmpty) {
          continue;
        }
        if (key == 'equation' ||
            key == 'function' ||
            key == 'func' ||
            key == 'expression') {
          value = normalizeExpression(value);
        }
      }

      sanitized[key] = value;
    }

    return sanitized;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    description,
    endpoint,
    fields,
    crossFieldRules,
    supportsGraph,
    supportsExplanation,
  ];
}

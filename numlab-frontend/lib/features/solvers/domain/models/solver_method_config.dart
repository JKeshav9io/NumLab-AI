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

import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_config.dart';

/// Status enum tracking the lifecycle of the solver form.
enum SolverFormStatus {
  /// Initial state before any solver has been loaded.
  initial,

  /// Loading the configuration metadata for the selected solver.
  loadingConfig,

  /// Configuration is loaded and the form is interactive and ready for input.
  ready,

  /// Solver execution is currently in progress.
  submitting,

  /// Solver execution succeeded with a valid [SolverResult].
  success,

  /// Configuration loading, validation, or solver execution failed.
  failure,
}

/// Immutable state container for the solver form presentation layer.
class SolverFormState extends Equatable {
  const SolverFormState({
    this.status = SolverFormStatus.initial,
    this.config,
    this.values = const {},
    this.fieldErrors = const {},
    this.touchedFields = const {},
    this.result,
    this.failure,
  });

  /// Current form lifecycle status.
  final SolverFormStatus status;

  /// Active solver metadata and field schema configuration.
  final SolverMethodConfig? config;

  /// Current map of input field values `{fieldName: value}`.
  final Map<String, dynamic> values;

  /// Current validation errors `{fieldNameOrRuleId: errorMessage}`.
  final Map<String, String> fieldErrors;

  /// Set of field keys that the user has interacted with or modified.
  final Set<String> touchedFields;

  /// Calculation result from successful execution.
  final SolverResult? result;

  /// Failure object if execution or configuration loading failed.
  final Failure? failure;

  /// Whether the form is in its uninitialized initial state.
  bool get isInitial => status == SolverFormStatus.initial;

  /// Whether solver configuration is currently loading.
  bool get isLoadingConfig => status == SolverFormStatus.loadingConfig;

  /// Whether the form is ready for interaction.
  bool get isReady => status == SolverFormStatus.ready;

  /// Whether the solver calculation is currently executing.
  bool get isSubmitting => status == SolverFormStatus.submitting;

  /// Whether any async operation (config load or execution) is running.
  bool get isLoading => isSubmitting || isLoadingConfig;

  /// Whether the last solver execution was successful.
  bool get isSuccess => status == SolverFormStatus.success;

  /// Whether the form is in a failure state.
  bool get isFailure => status == SolverFormStatus.failure;

  /// Whether a valid calculation result is present.
  bool get hasResult => result != null;

  /// Whether an execution or validation failure is present.
  bool get hasFailure => failure != null;

  /// Whether there are active validation errors on any field.
  bool get hasFieldErrors => fieldErrors.isNotEmpty;

  /// Whether the configuration is loaded and all current inputs are valid.
  bool get isValid => config != null && fieldErrors.isEmpty;

  /// Retrieves the value of a specific field by [fieldName].
  dynamic getValue(String fieldName) => values[fieldName];

  /// Retrieves the validation error for a specific field by [fieldName].
  String? getFieldError(String fieldName) => fieldErrors[fieldName];

  /// Convenience accessor for the error message derived from [failure].
  String? get errorMessage => failure?.message;

  /// Creates a copy of this state with specified fields replaced.
  SolverFormState copyWith({
    SolverFormStatus? status,
    SolverMethodConfig? config,
    bool clearConfig = false,
    Map<String, dynamic>? values,
    Map<String, String>? fieldErrors,
    Set<String>? touchedFields,
    SolverResult? result,
    bool clearResult = false,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return SolverFormState(
      status: status ?? this.status,
      config: clearConfig ? null : (config ?? this.config),
      values: values ?? this.values,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      touchedFields: touchedFields ?? this.touchedFields,
      result: clearResult ? null : (result ?? this.result),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    status,
    config,
    values,
    fieldErrors,
    touchedFields,
    result,
    failure,
  ];
}

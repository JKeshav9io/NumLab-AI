import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/domain/usecases/execute_solver_use_case.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/solver_form_event.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/solver_form_state.dart';

/// Generic BLoC managing dynamic solver form configuration, input state,
/// client-side validation, and execution for all 27 numerical solvers.
class SolverFormBloc extends Bloc<SolverFormEvent, SolverFormState> {
  SolverFormBloc({
    required ExecuteSolverUseCase executeSolverUseCase,
  }) : _executeSolverUseCase = executeSolverUseCase,
       super(const SolverFormState()) {
    on<SolverFormLoadStarted>(_onLoadStarted);
    on<SolverFormMethodSwitched>(_onMethodSwitched);
    on<SolverFormFieldChanged>(_onFieldChanged);
    on<SolverFormFieldsBulkChanged>(_onFieldsBulkChanged);
    on<SolverFormValidateRequested>(_onValidateRequested);
    on<SolverFormResetRequested>(_onResetRequested);
    on<SolverFormSubmitted>(_onSubmitted);
    on<SolverFormClearResultRequested>(_onClearResultRequested);
  }

  final ExecuteSolverUseCase _executeSolverUseCase;
  int _currentRequestId = 0;

  void _onLoadStarted(
    SolverFormLoadStarted event,
    Emitter<SolverFormState> emit,
  ) {
    _currentRequestId++;
    emit(
      state.copyWith(
        status: SolverFormStatus.loadingConfig,
        clearResult: true,
        clearFailure: true,
        fieldErrors: const {},
      ),
    );

    final config = SolverMethodRegistry.getById(event.solverId);
    if (config == null) {
      emit(
        state.copyWith(
          status: SolverFormStatus.failure,
          clearConfig: true,
          values: const {},
          fieldErrors: const {},
          touchedFields: const {},
          clearResult: true,
          failure: ValidationFailure(
            message: 'Unknown solver method: "${event.solverId}"',
            code: 'UNKNOWN_SOLVER_METHOD',
          ),
        ),
      );
      return;
    }

    final defaultValues = config.defaultPayload();
    final initialValues = event.initialValues != null
        ? {...defaultValues, ...event.initialValues!}
        : defaultValues;
    final initialTouched = event.initialValues != null
        ? event.initialValues!.keys.toSet()
        : <String>{};

    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        config: config,
        values: initialValues,
        fieldErrors: const {},
        touchedFields: initialTouched,
        clearResult: true,
        clearFailure: true,
      ),
    );
  }

  void _onMethodSwitched(
    SolverFormMethodSwitched event,
    Emitter<SolverFormState> emit,
  ) {
    final newConfig = SolverMethodRegistry.getById(event.solverId);
    if (newConfig == null) {
      emit(
        state.copyWith(
          status: SolverFormStatus.failure,
          failure: ValidationFailure(
            message: 'Unknown solver method: "${event.solverId}"',
            code: 'UNKNOWN_SOLVER_METHOD',
          ),
        ),
      );
      return;
    }

    // Invalidate in-flight solve and clear previous result and submission state
    _currentRequestId++;

    final oldConfig = state.config;
    final newValues = <String, dynamic>{};
    final newTouchedFields = <String>{};

    // Compatible values: carry over when field key AND input type match.
    // Fields not present in the new method are dropped.
    // New fields get their configured defaults.
    for (final field in newConfig.fields) {
      final oldField = oldConfig?.getField(field.name);
      if (oldField != null &&
          oldField.type == field.type &&
          state.values.containsKey(field.name)) {
        newValues[field.name] = state.values[field.name];
        if (state.touchedFields.contains(field.name)) {
          newTouchedFields.add(field.name);
        }
      } else {
        if (field.defaultValue != null) {
          newValues[field.name] = field.defaultValue;
        }
      }
    }

    // Clear all errors for removed fields, revalidate the resulting form,
    // but do NOT show errors on untouched fields.
    final allValidationErrors = newConfig.validate(newValues);
    final visibleErrors = <String, String>{};
    for (final entry in allValidationErrors.entries) {
      if (newTouchedFields.contains(entry.key)) {
        visibleErrors[entry.key] = entry.value;
      }
    }

    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        config: newConfig,
        values: newValues,
        fieldErrors: visibleErrors,
        touchedFields: newTouchedFields,
        clearResult: true,
        clearFailure: true,
      ),
    );
  }

  void _onFieldChanged(
    SolverFormFieldChanged event,
    Emitter<SolverFormState> emit,
  ) {
    final updatedValues = Map<String, dynamic>.from(state.values)
      ..[event.fieldName] = event.value;
    final updatedTouched = Set<String>.from(state.touchedFields)
      ..add(event.fieldName);

    final errors = state.config?.validate(updatedValues) ?? const {};

    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        values: updatedValues,
        fieldErrors: errors,
        touchedFields: updatedTouched,
        clearResult: true,
        clearFailure: true,
      ),
    );
  }

  void _onFieldsBulkChanged(
    SolverFormFieldsBulkChanged event,
    Emitter<SolverFormState> emit,
  ) {
    final updatedValues = Map<String, dynamic>.from(state.values)
      ..addAll(event.values);
    final updatedTouched = Set<String>.from(state.touchedFields)
      ..addAll(event.values.keys);

    final errors = state.config?.validate(updatedValues) ?? const {};

    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        values: updatedValues,
        fieldErrors: errors,
        touchedFields: updatedTouched,
        clearResult: true,
        clearFailure: true,
      ),
    );
  }

  void _onValidateRequested(
    SolverFormValidateRequested event,
    Emitter<SolverFormState> emit,
  ) {
    if (state.config == null) return;

    final errors = state.config!.validate(state.values);
    emit(
      state.copyWith(
        fieldErrors: errors,
      ),
    );
  }

  void _onResetRequested(
    SolverFormResetRequested event,
    Emitter<SolverFormState> emit,
  ) {
    if (state.config == null) return;

    _currentRequestId++;
    final defaultValues = state.config!.defaultPayload();
    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        values: defaultValues,
        fieldErrors: const {},
        touchedFields: const {},
        clearResult: true,
        clearFailure: true,
      ),
    );
  }

  Future<void> _onSubmitted(
    SolverFormSubmitted event,
    Emitter<SolverFormState> emit,
  ) async {
    // Guard against rapid duplicate submit clicks while calculation is already in-flight
    if (state.isSubmitting) {
      return;
    }

    final config = state.config;
    if (config == null) {
      emit(
        state.copyWith(
          status: SolverFormStatus.failure,
          failure: const ValidationFailure(
            message: 'No solver configuration loaded',
            code: 'CONFIG_NOT_LOADED',
          ),
        ),
      );
      return;
    }

    final validationErrors = config.validate(state.values);
    if (validationErrors.isNotEmpty) {
      final fieldErrorsList = validationErrors.entries
          .map((e) => FieldError(field: e.key, message: e.value))
          .toList(growable: false);

      emit(
        state.copyWith(
          status: SolverFormStatus.failure,
          fieldErrors: validationErrors,
          touchedFields: {
            ...state.touchedFields,
            ...config.fields.map((f) => f.name),
          },
          failure: ValidationFailure(
            message: 'Validation failed for ${config.name}',
            fieldErrors: fieldErrorsList,
          ),
        ),
      );
      return;
    }

    final requestId = ++_currentRequestId;

    emit(
      state.copyWith(
        status: SolverFormStatus.submitting,
        fieldErrors: const {},
        clearResult: true,
        clearFailure: true,
      ),
    );

    // Build payload strictly from the currently selected method's fields
    final allowedFieldNames = config.fields.map((f) => f.name).toSet();
    final filteredValues = <String, dynamic>{};
    for (final entry in state.values.entries) {
      if (allowedFieldNames.contains(entry.key)) {
        filteredValues[entry.key] = entry.value;
      }
    }
    final sanitizedPayload = SolverMethodConfig.sanitizePayload(filteredValues);

    final result = await _executeSolverUseCase(
      solverId: config.id,
      payload: sanitizedPayload,
      accessToken: event.accessToken,
    );

    // Stale results: ignore late response if method was switched or reset
    if (requestId != _currentRequestId) {
      return;
    }

    result.fold(
      (failure) {
        final mergedErrors =
            failure is ValidationFailure && failure.fieldErrors.isNotEmpty
            ? {
                for (final e in failure.fieldErrors) e.field: e.message,
              }
            : state.fieldErrors;

        emit(
          state.copyWith(
            status: SolverFormStatus.failure,
            failure: failure,
            fieldErrors: mergedErrors,
            clearResult: true,
          ),
        );
      },
      (solverResult) {
        emit(
          state.copyWith(
            status: SolverFormStatus.success,
            result: solverResult,
            fieldErrors: const {},
            clearFailure: true,
          ),
        );
      },
    );
  }

  void _onClearResultRequested(
    SolverFormClearResultRequested event,
    Emitter<SolverFormState> emit,
  ) {
    _currentRequestId++;
    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        clearResult: true,
        clearFailure: true,
      ),
    );
  }
}

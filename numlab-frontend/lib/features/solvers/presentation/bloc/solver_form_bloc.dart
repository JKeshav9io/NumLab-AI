import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_registry.dart';
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
    on<SolverFormFieldChanged>(_onFieldChanged);
    on<SolverFormFieldsBulkChanged>(_onFieldsBulkChanged);
    on<SolverFormValidateRequested>(_onValidateRequested);
    on<SolverFormResetRequested>(_onResetRequested);
    on<SolverFormSubmitted>(_onSubmitted);
    on<SolverFormClearResultRequested>(_onClearResultRequested);
  }

  final ExecuteSolverUseCase _executeSolverUseCase;

  void _onLoadStarted(
    SolverFormLoadStarted event,
    Emitter<SolverFormState> emit,
  ) {
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

    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        config: config,
        values: initialValues,
        fieldErrors: const {},
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

    final errors = state.config?.validate(updatedValues) ?? const {};

    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        values: updatedValues,
        fieldErrors: errors,
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

    final errors = state.config?.validate(updatedValues) ?? const {};

    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        values: updatedValues,
        fieldErrors: errors,
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

    final defaultValues = state.config!.defaultPayload();
    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        values: defaultValues,
        fieldErrors: const {},
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
          failure: ValidationFailure(
            message: 'Validation failed for ${config.name}',
            fieldErrors: fieldErrorsList,
          ),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SolverFormStatus.submitting,
        fieldErrors: const {},
        clearResult: true,
        clearFailure: true,
      ),
    );

    final result = await _executeSolverUseCase(
      solverId: config.id,
      payload: state.values,
      accessToken: event.accessToken,
    );

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
    emit(
      state.copyWith(
        status: SolverFormStatus.ready,
        clearResult: true,
        clearFailure: true,
      ),
    );
  }
}

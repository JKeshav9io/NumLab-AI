import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/dynamic_form/dynamic_boolean_field.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/dynamic_form/dynamic_matrix_field.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/dynamic_form/dynamic_point_list_field.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/dynamic_form/dynamic_select_field.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/dynamic_form/dynamic_text_field.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/dynamic_form/dynamic_vector_field.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_result_view.dart';

/// Generic dynamic input form driven completely by [SolverMethodConfig.fields].
///
/// Features:
/// - Renders appropriate input controls dynamically based on field types.
/// - Dispatches input updates to [SolverFormBloc].
/// - Displays field-level and cross-field validation errors.
/// - Supports reset to schema defaults.
/// - Provides calculation execution triggers and loading state.
class DynamicSolverForm extends StatelessWidget {
  const DynamicSolverForm({
    required this.config,
    required this.state,
    super.key,
  });

  final SolverMethodConfig config;
  final SolverFormState state;

  @override
  Widget build(BuildContext context) {
    // Identify cross-field errors (errors whose key does not belong to a single field)
    final fieldNames = config.fields.map((f) => f.name).toSet();
    final crossFieldErrors = state.fieldErrors.entries
        .where((entry) => !fieldNames.contains(entry.key))
        .toList();

    return Column(
      key: const Key('dynamic_solver_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Cross-field Validation Error Alert
        if (crossFieldErrors.isNotEmpty)
          Container(
            key: const Key('cross_field_error_banner'),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Validation Errors',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ...crossFieldErrors.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• ${e.value}',
                      key: Key('cross_field_error_${e.key}'),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

        // 2. Dynamic Input Fields
        ...config.fields.map((field) {
          final value = state.getValue(field.name) ?? field.defaultValue;
          final errorText = state.getFieldError(field.name);

          return _buildFieldWidget(
            context: context,
            field: field,
            value: value,
            errorText: errorText,
          );
        }),

        const SizedBox(height: AppSpacing.md),

        // 3. Form Action Buttons (Reset & Run Solver)
        Row(
          children: [
            OutlinedButton.icon(
              key: const Key('solver_reset_button'),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset'),
              onPressed: state.isSubmitting
                  ? null
                  : () {
                      context.read<SolverFormBloc>().add(
                        const SolverFormResetRequested(),
                      );
                    },
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('solver_submit_button'),
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  state.isSubmitting ? 'Calculating...' : 'Run Solver',
                ),
                onPressed: state.isSubmitting
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        context.read<SolverFormBloc>().add(
                          const SolverFormSubmitted(),
                        );
                      },
              ),
            ),
          ],
        ),

        // 4. Execution Error Banner
        if (state.isFailure &&
            state.errorMessage != null &&
            crossFieldErrors.isEmpty &&
            state.fieldErrors.isEmpty)
          Container(
            key: const Key('solver_execution_error_banner'),
            margin: const EdgeInsets.only(top: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              state.errorMessage!,
              key: const Key('solver_execution_error'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),

        // 5. Calculation Result
        if (state.hasResult)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: SolverResultView(result: state.result!),
          ),
      ],
    );
  }

  Widget _buildFieldWidget({
    required BuildContext context,
    required SolverInputFieldConfig field,
    required dynamic value,
    required String? errorText,
  }) {
    final bloc = context.read<SolverFormBloc>();

    switch (field.type) {
      case SolverInputFieldType.equation:
      case SolverInputFieldType.number:
      case SolverInputFieldType.integer:
        return DynamicTextField(
          config: field,
          value: value,
          errorText: errorText,
          onChanged: (newValue) {
            bloc.add(
              SolverFormFieldChanged(fieldName: field.name, value: newValue),
            );
          },
        );

      case SolverInputFieldType.boolean:
        return DynamicBooleanField(
          config: field,
          value: value == true,
          onChanged: (newValue) {
            bloc.add(
              SolverFormFieldChanged(fieldName: field.name, value: newValue),
            );
          },
        );

      case SolverInputFieldType.select:
        return DynamicSelectField(
          config: field,
          value: value?.toString(),
          errorText: errorText,
          onChanged: (newValue) {
            bloc.add(
              SolverFormFieldChanged(fieldName: field.name, value: newValue),
            );
          },
        );

      case SolverInputFieldType.vector:
        return DynamicVectorField(
          config: field,
          value: value,
          errorText: errorText,
          onChanged: (newValue) {
            bloc.add(
              SolverFormFieldChanged(fieldName: field.name, value: newValue),
            );
          },
        );

      case SolverInputFieldType.matrix:
        return DynamicMatrixField(
          config: field,
          value: value,
          errorText: errorText,
          onChanged: (newValue) {
            bloc.add(
              SolverFormFieldChanged(fieldName: field.name, value: newValue),
            );
          },
        );

      case SolverInputFieldType.pointList:
        return DynamicPointListField(
          config: field,
          value: value,
          errorText: errorText,
          onChanged: (newValue) {
            bloc.add(
              SolverFormFieldChanged(fieldName: field.name, value: newValue),
            );
          },
        );
    }
  }
}

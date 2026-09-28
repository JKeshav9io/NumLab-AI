import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/widgets.dart';

/// Functional host screen for solver form workflows.
///
/// Features:
/// - Connects directly to [SolverFormBloc] without solver-specific screens.
/// - Embeds [DynamicSolverForm] which generates inputs dynamically from solver config fields.
/// - Displays solver metadata, status, dynamic inputs, validation errors, and execution results.
class SolverFormScreen extends StatelessWidget {
  const SolverFormScreen({
    required this.solverId,
    super.key,
  });

  final String solverId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SolverFormBloc, SolverFormState>(
      builder: (context, state) {
        if (state.isLoadingConfig) {
          return const Scaffold(
            key: Key('solver_form_screen'),
            body: Center(
              child: CircularProgressIndicator(
                key: Key('solver_loading_indicator'),
              ),
            ),
          );
        }

        if (state.isFailure && state.config == null) {
          return Scaffold(
            key: const Key('solver_form_screen'),
            appBar: AppBar(
              title: const Text('Solver'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.errorMessage ?? 'Failed to load solver "$solverId"',
                      key: const Key('solver_error_message'),
                      textAlign: TextAlign.center,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      key: const Key('solver_back_button'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final config = state.config;
        if (config == null) {
          return const Scaffold(
            key: Key('solver_form_screen'),
            body: Center(
              child: Text(
                'No solver loaded',
                key: Key('solver_unloaded_text'),
              ),
            ),
          );
        }

        return Scaffold(
          key: const Key('solver_form_screen'),
          appBar: AppBar(
            title: Text(config.name, key: const Key('solver_appbar_title')),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Category Header
                  Text(
                    config.name,
                    key: const Key('solver_name'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Chip(
                        key: const Key('solver_category'),
                        label: Text(config.category.displayName),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Chip(
                        key: const Key('solver_status'),
                        label: Text('Status: ${state.status.name}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    config.description,
                    key: const Key('solver_description'),
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'API Endpoint: ${config.endpoint}',
                    key: const Key('solver_endpoint'),
                    style: AppTypography.codeMono.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Dynamic Solver Form (all fields, validation, buttons, and results)
                  DynamicSolverForm(
                    config: config,
                    state: state,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

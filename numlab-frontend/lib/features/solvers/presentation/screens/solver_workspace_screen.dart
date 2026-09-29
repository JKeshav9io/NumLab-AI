import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/widgets.dart';

/// Category Workspace Screen hosting the hybrid Solver Workspace UX.
///
/// Features:
/// - Category-first workflow: Home → Category → Category Workspace → Method Selector → Dynamic Form → Result.
/// - Responsive Method Selector: visible selectable options on wide layouts, compact dropdown on narrow layouts.
/// - Deep-linking & location persistence via URL query parameter `?method=:methodId`.
/// - State-safe method switching preserving compatible inputs and suppressing untouched field errors.
class SolverWorkspaceScreen extends StatefulWidget {
  const SolverWorkspaceScreen({
    required this.categoryId,
    this.initialMethodId,
    super.key,
  });

  /// The category slug identifier (e.g. 'root-finding', 'linear-algebra').
  final String categoryId;

  /// Optional preselected solver method identifier from query parameters or deep link.
  final String? initialMethodId;

  @override
  State<SolverWorkspaceScreen> createState() => _SolverWorkspaceScreenState();
}

class _SolverWorkspaceScreenState extends State<SolverWorkspaceScreen> {
  late final SolverCategory? _category;
  late final List<SolverMethodConfig> _methods;

  @override
  void initState() {
    super.initState();
    final category = SolverCategory.fromId(widget.categoryId);
    _category = category;
    _methods = category != null
        ? SolverMethodRegistry.getByCategory(category)
        : const [];

    if (_methods.isNotEmpty) {
      final initialMethod = _resolveInitialMethod();
      context.read<SolverFormBloc>().add(
        SolverFormLoadStarted(solverId: initialMethod.id),
      );
    }
  }

  @override
  void didUpdateWidget(SolverWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMethodId != oldWidget.initialMethodId &&
        widget.initialMethodId != null) {
      final currentConfig = context.read<SolverFormBloc>().state.config;
      if (currentConfig?.id != widget.initialMethodId) {
        context.read<SolverFormBloc>().add(
          SolverFormMethodSwitched(solverId: widget.initialMethodId!),
        );
      }
    }
  }

  SolverMethodConfig _resolveInitialMethod() {
    if (widget.initialMethodId != null) {
      for (final method in _methods) {
        if (method.id == widget.initialMethodId) {
          return method;
        }
      }
    }
    return _methods.first;
  }

  void _onMethodSelected(String methodId) {
    final category = _category;
    if (category == null) return;
    if (GoRouter.maybeOf(context) != null) {
      context.go(AppRoutes.workspace(category.id, methodId));
    }
    context.read<SolverFormBloc>().add(
      SolverFormMethodSwitched(solverId: methodId),
    );
  }

  IconData _getCategoryIcon(SolverCategory category) {
    switch (category) {
      case SolverCategory.rootFinding:
        return Icons.adjust;
      case SolverCategory.linearAlgebra:
        return Icons.grid_on;
      case SolverCategory.interpolation:
        return Icons.show_chart;
      case SolverCategory.ode:
        return Icons.trending_up;
      case SolverCategory.integration:
        return Icons.area_chart;
      case SolverCategory.differentiation:
        return Icons.timeline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    if (category == null || _methods.isEmpty) {
      return Scaffold(
        key: const Key('solver_workspace_screen'),
        appBar: AppBar(
          title: const Text('Workspace'),
          leading: IconButton(
            key: const Key('workspace_back_button'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.home),
          ),
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
                  'Unknown or empty category: "${widget.categoryId}"',
                  key: const Key('workspace_error_message'),
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  key: const Key('workspace_go_home_button'),
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Home'),
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BlocBuilder<SolverFormBloc, SolverFormState>(
      builder: (context, state) {
        if (state.isLoadingConfig) {
          return Scaffold(
            key: const Key('solver_workspace_screen'),
            appBar: AppBar(
              title: Text(category.displayName),
              leading: IconButton(
                key: const Key('workspace_back_button'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.home),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                key: Key('solver_loading_indicator'),
              ),
            ),
          );
        }

        final activeConfig = state.config ?? _resolveInitialMethod();

        return Scaffold(
          key: const Key('solver_workspace_screen'),
          appBar: AppBar(
            title: Text(
              category.displayName,
              key: const Key('category_workspace_title'),
            ),
            leading: IconButton(
              key: const Key('workspace_back_button'),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Home',
              onPressed: () => context.go(AppRoutes.home),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                key: const Key('solver_form_screen'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Category Banner & Info Header
                  _buildCategoryHeader(context, category, activeConfig),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Responsive Method Selector
                  _buildResponsiveMethodSelector(context, activeConfig),
                  const SizedBox(height: AppSpacing.lg),

                  // 3. Dynamic Method Form & Result Flow
                  DynamicSolverForm(
                    config: activeConfig,
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

  Widget _buildCategoryHeader(
    BuildContext context,
    SolverCategory category,
    SolverMethodConfig activeConfig,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(
                  _getCategoryIcon(category),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      category.description,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Active Method: ${activeConfig.name}',
            key: const Key('active_method_name_display'),
            style: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            activeConfig.description,
            key: const Key('solver_description'),
            style: AppTypography.bodyMedium.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveMethodSelector(
    BuildContext context,
    SolverMethodConfig activeConfig,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint threshold: 600 px
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return _buildWideMethodSelector(activeConfig);
        } else {
          return _buildCompactMethodSelector(activeConfig);
        }
      },
    );
  }

  Widget _buildWideMethodSelector(SolverMethodConfig activeConfig) {
    return Column(
      key: const Key('method_selector_wide'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Solver Method',
          style: AppTypography.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: _methods.map((method) {
            final isSelected = method.id == activeConfig.id;
            return ChoiceChip(
              key: Key('method_chip_${method.id}'),
              label: Text(method.name),
              selected: isSelected,
              onSelected: (selected) {
                if (selected && method.id != activeConfig.id) {
                  _onMethodSelected(method.id);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompactMethodSelector(SolverMethodConfig activeConfig) {
    return Column(
      key: const Key('method_selector_compact'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Solver Method',
          style: AppTypography.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('method_selector_dropdown'),
              value: activeConfig.id,
              isDense: true,
              isExpanded: true,
              items: _methods.map((method) {
                return DropdownMenuItem<String>(
                  key: Key('method_dropdown_item_${method.id}'),
                  value: method.id,
                  child: Text(method.name),
                );
              }).toList(),
              onChanged: (selectedId) {
                if (selectedId != null && selectedId != activeConfig.id) {
                  _onMethodSelected(selectedId);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

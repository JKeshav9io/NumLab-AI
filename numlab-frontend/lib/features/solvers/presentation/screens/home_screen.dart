import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

/// Main functional landing and solver selection screen.
///
/// Features:
/// - Category filtering for all 6 numerical solver categories.
/// - Dynamic listing of all 27 solvers sourced directly from [SolverMethodRegistry].
/// - Tap-to-navigate solver launching to the solver form pipeline.
/// - Integrated user session status banner and navigation to auth flows.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SolverCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final solvers = _selectedCategory == null
        ? SolverMethodRegistry.all
        : SolverMethodRegistry.getByCategory(_selectedCategory!);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        return Scaffold(
          key: const Key('home_screen'),
          appBar: AppBar(
            title: const Text('NumLab AI'),
            actions: [
              if (authState is AuthAuthenticated)
                IconButton(
                  key: const Key('appbar_profile_button'),
                  tooltip: 'Profile',
                  icon: const Icon(Icons.person),
                  onPressed: () => context.go(AppRoutes.profile),
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Authentication / User Session Banner
                  _buildAuthBanner(context, authState, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // Header Title
                  Text(
                    'Numerical Solvers',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Select an algorithm category or choose from all 27 solvers below.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Category Filter Chips
                  _buildCategoryFilterSection(),
                  const SizedBox(height: AppSpacing.md),

                  // Solvers Count & Heading
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCategory == null
                            ? 'All Solvers (${solvers.length})'
                            : '${_selectedCategory!.displayName} (${solvers.length})',
                        key: const Key('solvers_count_text'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_selectedCategory != null)
                        TextButton(
                          key: const Key('clear_filter_button'),
                          onPressed: () =>
                              setState(() => _selectedCategory = null),
                          child: const Text('Show All'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Solvers List
                  if (solvers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'No solvers found in this category.',
                          key: Key('empty_solvers_text'),
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                    )
                  else
                    ...solvers.map(
                      (solver) => _buildSolverCard(context, solver, isDark),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: AppTypography.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                key: const Key('category_chip_all'),
                label: const Text('All (27)'),
                selected: _selectedCategory == null,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategory = null);
                  }
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              ...SolverCategory.values.map((category) {
                final categorySolversCount = SolverMethodRegistry.getByCategory(
                  category,
                ).length;
                final isSelected = _selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    key: Key('category_chip_${category.id}'),
                    label: Text(
                      '${category.displayName} ($categorySolversCount)',
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : null;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSolverCard(
    BuildContext context,
    SolverMethodConfig solver,
    bool isDark,
  ) {
    return Card(
      key: Key('solver_card_${solver.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ListTile(
        key: Key('solver_tile_${solver.id}'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(
            _getCategoryIcon(solver.category),
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          solver.name,
          key: Key('solver_title_${solver.id}'),
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Text(
              solver.description,
              key: Key('solver_desc_${solver.id}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    solver.category.displayName,
                    key: Key('solver_category_badge_${solver.id}'),
                    style: AppTypography.labelSmall.copyWith(fontSize: 11),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${solver.fields.length} inputs',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          unawaited(context.push(AppRoutes.solver(solver.id)));
        },
      ),
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

  Widget _buildAuthBanner(
    BuildContext context,
    AuthState state,
    bool isDark,
  ) {
    if (state is AuthLoading) {
      return const Card(
        key: Key('auth_loading_card'),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.hourglass_top, color: AppColors.primary, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Restoring session...',
                key: Key('session_restoring_text'),
                style: AppTypography.labelSmall,
              ),
            ],
          ),
        ),
      );
    }

    if (state is AuthAuthenticated) {
      final user = state.user;
      return Card(
        key: const Key('authenticated_user_card'),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.success, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_circle,
                    color: AppColors.success,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Authenticated Session',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const Key('home_to_profile_button'),
                    icon: const Icon(Icons.person, size: 16),
                    label: const Text('Profile'),
                    onPressed: () => context.go(AppRoutes.profile),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  TextButton.icon(
                    key: const Key('logout_button'),
                    icon: const Icon(
                      Icons.logout,
                      size: 16,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthLogoutRequested());
                    },
                  ),
                ],
              ),
              const Divider(height: 12),
              Text(
                'ID: ${user.id}',
                key: const Key('user_id_display'),
                style: AppTypography.labelSmall,
              ),
              Text(
                'Email: ${user.email}',
                key: const Key('user_email_display'),
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Verified: ${user.emailVerified}',
                key: const Key('user_verified_display'),
                style: AppTypography.labelSmall,
              ),
            ],
          ),
        ),
      );
    }

    // Unauthenticated banner
    return Card(
      key: const Key('unauthenticated_session_card'),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Guest Session',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Solvers are available anonymously. Sign in to save calculation history.',
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: const Key('home_login_button'),
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Login'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('home_register_button'),
                    onPressed: () => context.go(AppRoutes.register),
                    child: const Text('Register'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

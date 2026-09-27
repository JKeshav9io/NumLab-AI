import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';

/// Phase 0 & Phase 1 Placeholder Home Screen verifying architecture scaffold
/// and displaying authenticated user session status with functional logout.
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('NumLab AI'),
            actions: [
              if (state is AuthAuthenticated)
                IconButton(
                  key: const Key('appbar_profile_button'),
                  tooltip: 'Profile',
                  icon: const Icon(Icons.person),
                  onPressed: () => context.go(AppRoutes.profile),
                ),
              IconButton(
                tooltip: 'Scaffold Status: Operational',
                icon: const Icon(Icons.check_circle, color: AppColors.success),
                onPressed: () {},
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Authentication Session Banner
                  _buildAuthSessionCard(context, state, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phase 0 Architecture Scaffold',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Numerical Computing Platform Mobile Client',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                          ),
                          child: Text(
                            'Base URL: ${ApiConstants.defaultBaseUrl}',
                            style: AppTypography.codeMono.copyWith(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Text(
                    'Architecture Verification',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Architectural Checklist Cards
                  _buildStatusTile(
                    context,
                    icon: Icons.architecture,
                    title: 'Clean Architecture Topology',
                    subtitle: 'core/, features/, shared/ layered hierarchy',
                    isDark: isDark,
                  ),
                  _buildStatusTile(
                    context,
                    icon: Icons.layers_outlined,
                    title: 'BLoC & Equatable State Management',
                    subtitle:
                        'Zero build_runner code-gen overhead, instant reloads',
                    isDark: isDark,
                  ),
                  _buildStatusTile(
                    context,
                    icon: Icons.alt_route,
                    title: 'GoRouter Declarative Navigation',
                    subtitle:
                        'Configured with Phase 1 Auth Guard extension hook',
                    isDark: isDark,
                  ),
                  _buildStatusTile(
                    context,
                    icon: Icons.http,
                    title: 'Dio Network Client',
                    subtitle:
                        'Debug logging & silent refresh QueuedInterceptor stub',
                    isDark: isDark,
                  ),
                  _buildStatusTile(
                    context,
                    icon: Icons.security,
                    title: 'Encrypted Secure Storage',
                    subtitle: 'Keychain (iOS) & Encrypted storage (Android)',
                    isDark: isDark,
                  ),
                  _buildStatusTile(
                    context,
                    icon: Icons.error_outline,
                    title: 'Sealed Failure Hierarchy & Error Mapper',
                    subtitle:
                        'Network, Server, Auth, Validation & RateLimit failures',
                    isDark: isDark,
                  ),
                  _buildStatusTile(
                    context,
                    icon: Icons.functions,
                    title: 'fpdart Either<Failure, T> Ready',
                    subtitle:
                        'Type-safe functional domain and repository contracts',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthSessionCard(
    BuildContext context,
    AuthState state,
    bool isDark,
  ) {
    if (state is AuthLoading) {
      return Card(
        key: const Key('auth_loading_card'),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Padding(
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
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.success, width: 1.5),
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
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Authenticated User',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const Divider(),
              Text(
                'ID: ${user.id}',
                key: const Key('user_id_display'),
                style: AppTypography.labelSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Email: ${user.email}',
                key: const Key('user_email_display'),
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Verified: ${user.emailVerified}',
                key: const Key('user_verified_display'),
                style: AppTypography.labelSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('home_to_profile_button'),
                      icon: const Icon(Icons.person, size: 18),
                      label: const Text('View Profile'),
                      onPressed: () => context.go(AppRoutes.profile),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('logout_button'),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        context.read<AuthBloc>().add(
                          const AuthLogoutRequested(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Unauthenticated, Initial, or Error state banner
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
            if (state is AuthError) ...[
              Container(
                key: const Key('auth_error_banner'),
                padding: const EdgeInsets.all(AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        state.message,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Authentication Flow (Phase 1)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Sign in or register an account to access authenticated features.',
              style: AppTypography.labelSmall,
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

  Widget _buildStatusTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: AppTypography.titleMedium.copyWith(fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodyMedium.copyWith(fontSize: 12),
        ),
        trailing: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 20,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/core/theme/app_colors.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';

/// Minimal functional profile screen displaying authenticated user information
/// and supporting refresh, logout, and logout-all actions.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key = const Key('profile_screen')});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            key: const Key('profile_refresh_icon_button'),
            tooltip: 'Refresh Profile',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AuthBloc>().add(const AuthGetCurrentUserRequested());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  key: Key('profile_loading_indicator'),
                ),
              );
            }

            if (state is AuthError) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      key: const Key('auth_error_banner'),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.error),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
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
                    ElevatedButton.icon(
                      key: const Key('profile_retry_button'),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      onPressed: () {
                        context.read<AuthBloc>().add(
                          const AuthGetCurrentUserRequested(),
                        );
                      },
                    ),
                  ],
                ),
              );
            }

            if (state is AuthAuthenticated) {
              final user = state.user;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        side: const BorderSide(
                          color: AppColors.success,
                          width: 1.5,
                        ),
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
                                  size: 28,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'User Profile',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              'ID: ${user.id}',
                              key: const Key('profile_user_id'),
                              style: AppTypography.labelSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Email: ${user.email}',
                              key: const Key('profile_user_email'),
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Verified: ${user.emailVerified}',
                              key: const Key('profile_user_verified'),
                              style: AppTypography.labelSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Created: ${user.createdAt.toIso8601String()}',
                              key: const Key('profile_created_at'),
                              style: AppTypography.labelSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Last Login: ${user.lastLoginAt?.toIso8601String() ?? "Never"}',
                              key: const Key('profile_last_login_at'),
                              style: AppTypography.labelSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Updated: ${user.updatedAt?.toIso8601String() ?? "Never"}',
                              key: const Key('profile_updated_at'),
                              style: AppTypography.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      key: const Key('profile_refresh_button'),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh Profile'),
                      onPressed: () {
                        context.read<AuthBloc>().add(
                          const AuthGetCurrentUserRequested(),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton.icon(
                      key: const Key('profile_logout_button'),
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
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const Key('profile_logout_all_button'),
                      icon: const Icon(Icons.phonelink_erase, size: 18),
                      label: const Text('Logout All Sessions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: () {
                        context.read<AuthBloc>().add(
                          const AuthLogoutAllRequested(),
                        );
                      },
                    ),
                  ],
                ),
              );
            }

            if (state is AuthUnauthenticated) {
              return const Center(
                child: Text(
                  'Unauthenticated. Redirecting to login...',
                  key: Key('profile_unauthenticated_text'),
                ),
              );
            }

            return const Center(
              child: Text(
                'Initializing session...',
                key: Key('profile_initial_text'),
              ),
            );
          },
        ),
      ),
    );
  }
}

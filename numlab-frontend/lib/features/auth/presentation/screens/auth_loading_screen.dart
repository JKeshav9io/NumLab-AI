import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';

/// Minimal loading screen displayed while AuthBloc restores a session.
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({
    super.key = const Key('auth_loading_screen'),
    this.message = 'Restoring session...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              key: Key('auth_loading_indicator'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              key: const Key('auth_loading_message'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

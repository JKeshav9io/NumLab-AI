import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/theme/app_theme.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/injection_container.dart';

/// Root application widget configured with GoRouter, AuthBloc, and centralized themes.
class NumLabApp extends StatelessWidget {
  const NumLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = sl<AppRouter>();

    return BlocProvider<AuthBloc>.value(
      value: sl<AuthBloc>(),
      child: MaterialApp.router(
        title: 'NumLab AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        routerConfig: appRouter.router,
      ),
    );
  }
}

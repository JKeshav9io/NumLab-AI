import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/auth/presentation/screens/screens.dart';
import 'package:numlab_frontend/features/profile/presentation/profile_screen.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/presentation/screens/screens.dart';
import 'package:numlab_frontend/injection_container.dart';

/// Central application route constants and path utilities.
abstract final class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String solverPrefix = '/solver';
  static const String workspacePrefix = '/workspace';
  static const String history = '/history';
  static const String profile = '/profile';

  /// Builds a solver path for the specified [id].
  static String solver(String id) => '$solverPrefix/$id';

  /// Builds a category workspace path for the specified [categoryId],
  /// optionally preselecting a [methodId].
  static String workspace(String categoryId, [String? methodId]) {
    if (methodId != null && methodId.isNotEmpty) {
      return '$workspacePrefix/$categoryId?method=$methodId';
    }
    return '$workspacePrefix/$categoryId';
  }

  /// Returns true if [location] requires an authenticated session.
  static bool isProtectedRoute(String location) {
    return location == profile ||
        location.startsWith('$profile/') ||
        location == history ||
        location.startsWith('$history/');
  }

  /// Returns true if [location] is an authentication entry route.
  static bool isAuthRoute(String location) {
    return location == login ||
        location.startsWith('$login/') ||
        location == register ||
        location.startsWith('$register/');
  }
}

/// Bridges a [Stream] to a [ChangeNotifier] for GoRouter.refreshListenable.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// Central routing management using [GoRouter] with authentication route protection.
class AppRouter {
  AppRouter({
    AuthBloc? authBloc,
    String? initialLocation,
  }) : _authBloc = authBloc ?? sl<AuthBloc>() {
    _refreshStream = GoRouterRefreshStream(_authBloc.stream);
    _router = GoRouter(
      initialLocation: initialLocation ?? AppRoutes.home,
      refreshListenable: _refreshStream,
      redirect: _authGuardRedirect,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          builder: (context, state) => BlocProvider.value(
            value: _authBloc,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '${AppRoutes.workspacePrefix}/:categoryId',
          name: 'workspace',
          builder: (context, state) {
            final categoryId = state.pathParameters['categoryId'] ?? '';
            final methodId = state.uri.queryParameters['method'];
            return BlocProvider<SolverFormBloc>(
              create: (_) => sl<SolverFormBloc>(),
              child: SolverWorkspaceScreen(
                categoryId: categoryId,
                initialMethodId: methodId,
              ),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.solverPrefix}/:solverId',
          name: 'solver',
          redirect: (context, state) {
            final solverId = state.pathParameters['solverId'] ?? '';
            final config = SolverMethodRegistry.getById(solverId);
            if (config != null) {
              return AppRoutes.workspace(config.category.id, config.id);
            }
            return AppRoutes.home;
          },
        ),
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          builder: (context, state) => BlocProvider.value(
            value: _authBloc,
            child: const LoginScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.register,
          name: 'register',
          builder: (context, state) => BlocProvider.value(
            value: _authBloc,
            child: const RegisterScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.profile,
          name: 'profile',
          builder: (context, state) => BlocProvider.value(
            value: _authBloc,
            child: const ProfileScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.history,
          name: 'history',
          builder: (context, state) => const Scaffold(
            key: Key('history_screen'),
            body: Center(child: Text('History Screen')),
          ),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('No route defined for ${state.uri}'),
        ),
      ),
    );
  }

  final AuthBloc _authBloc;
  late final GoRouterRefreshStream _refreshStream;
  late final GoRouter _router;

  GoRouter get router => _router;

  /// Route guard redirect handler that reacts to [AuthBloc] state changes.
  String? _authGuardRedirect(BuildContext context, GoRouterState state) {
    final authState = _authBloc.state;
    final matchedLocation = state.matchedLocation;

    final isAuth = authState is AuthAuthenticated;
    final isInitializing = authState is AuthInitial || authState is AuthLoading;

    final isProtected = AppRoutes.isProtectedRoute(matchedLocation);
    final isAuthPath = AppRoutes.isAuthRoute(matchedLocation);

    // 1. Session restoration / initial loading:
    // Must NOT cause premature or incorrect redirects before session state is determined.
    if (isInitializing) {
      return null;
    }

    // 2. Unauthenticated access to protected route:
    // Redirect to login, preserving intended destination via query parameter where possible.
    if (!isAuth && isProtected) {
      final fromParam = Uri.encodeComponent(state.uri.toString());
      return '${AppRoutes.login}?from=$fromParam';
    }

    // 3. Authenticated user visiting Login/Register:
    // Redirect to the intended destination (?from=...) or the authenticated landing route (home '/').
    if (isAuth && isAuthPath) {
      final fromParam = state.uri.queryParameters['from'];
      if (fromParam != null &&
          fromParam.isNotEmpty &&
          !fromParam.startsWith(AppRoutes.login) &&
          !fromParam.startsWith(AppRoutes.register)) {
        return Uri.decodeComponent(fromParam);
      }
      return AppRoutes.home;
    }

    // 4. Default: No redirect needed.
    return null;
  }

  void dispose() {
    _refreshStream.dispose();
    _router.dispose();
  }
}

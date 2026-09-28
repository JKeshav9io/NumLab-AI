import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/presentation/screens/screens.dart';

class MockAuthBloc extends Fake implements AuthBloc {
  MockAuthBloc(this._initialState) {
    _state = _initialState;
  }

  final AuthState _initialState;
  late AuthState _state;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  void emitState(AuthState newState) {
    _state = newState;
    _controller.add(newState);
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  group('AppRoutes Helper Methods', () {
    test('isProtectedRoute correctly identifies protected endpoints', () {
      expect(AppRoutes.isProtectedRoute('/profile'), isTrue);
      expect(AppRoutes.isProtectedRoute('/profile/edit'), isTrue);
      expect(AppRoutes.isProtectedRoute('/history'), isTrue);
      expect(AppRoutes.isProtectedRoute('/history/123'), isTrue);

      expect(AppRoutes.isProtectedRoute('/'), isFalse);
      expect(AppRoutes.isProtectedRoute('/login'), isFalse);
      expect(AppRoutes.isProtectedRoute('/register'), isFalse);
      expect(AppRoutes.isProtectedRoute('/solver/root/bisection'), isFalse);
    });

    test('isAuthRoute correctly identifies authentication entry points', () {
      expect(AppRoutes.isAuthRoute('/login'), isTrue);
      expect(AppRoutes.isAuthRoute('/login/reset'), isTrue);
      expect(AppRoutes.isAuthRoute('/register'), isTrue);

      expect(AppRoutes.isAuthRoute('/'), isFalse);
      expect(AppRoutes.isAuthRoute('/profile'), isFalse);
      expect(AppRoutes.isAuthRoute('/history'), isFalse);
    });
  });

  group('AppRouter Route Protection & Guards', () {
    late MockAuthBloc mockAuthBloc;
    late AppRouter appRouter;

    final tUser = User(
      id: 'test-user-id',
      email: 'student@example.com',
      emailVerified: true,
      createdAt: DateTime.parse('2026-09-26T12:00:00.000Z'),
    );

    tearDown(() async {
      appRouter.dispose();
      await mockAuthBloc.close();
    });

    testWidgets(
      'Unauthenticated → protected route redirects to /login preserving destination',
      (tester) async {
        mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.profile,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('login_screen')), findsOneWidget);
        expect(find.byKey(const Key('profile_screen')), findsNothing);

        final currentUri = appRouter.router.routeInformationProvider.value.uri;
        expect(currentUri.path, AppRoutes.login);
        expect(currentUri.queryParameters['from'], AppRoutes.profile);
      },
    );

    testWidgets(
      'Authenticated → protected route allows access',
      (tester) async {
        mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.profile,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsOneWidget);
        expect(find.byKey(const Key('login_screen')), findsNothing);
      },
    );

    testWidgets(
      'Authenticated → Login redirects to home landing route',
      (tester) async {
        mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.login,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byKey(const Key('login_screen')), findsNothing);
      },
    );

    testWidgets(
      'Authenticated → Register redirects to home landing route',
      (tester) async {
        mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.register,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byKey(const Key('register_screen')), findsNothing);
      },
    );

    testWidgets(
      'Logout immediately revokes access to protected route and redirects to /login',
      (tester) async {
        mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.profile,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsOneWidget);

        // User logs out -> AuthBloc emits AuthUnauthenticated
        mockAuthBloc.emitState(const AuthUnauthenticated());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('login_screen')), findsOneWidget);
        expect(find.byKey(const Key('profile_screen')), findsNothing);
      },
    );

    testWidgets(
      'Session restoration does not cause premature redirect during AuthInitial or AuthLoading',
      (tester) async {
        mockAuthBloc = MockAuthBloc(const AuthInitial());
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.profile,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        // Initially on loading / initial check:
        await tester.pump();
        expect(find.byKey(const Key('profile_screen')), findsOneWidget);
        expect(find.byKey(const Key('login_screen')), findsNothing);

        // Transition to loading:
        mockAuthBloc.emitState(const AuthLoading());
        await tester.pump();
        expect(find.byKey(const Key('login_screen')), findsNothing);

        // Restoration resolves:
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsOneWidget);
        expect(find.byKey(const Key('login_screen')), findsNothing);
      },
    );

    testWidgets(
      'Session revocation from interceptor redirects protected screen to /login',
      (tester) async {
        mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.history,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('history_screen')), findsOneWidget);

        // Interceptor reports session revocation -> AuthBloc emits AuthUnauthenticated
        mockAuthBloc.emitState(
          const AuthUnauthenticated(message: 'Session revoked'),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('login_screen')), findsOneWidget);
        expect(find.byKey(const Key('history_screen')), findsNothing);
      },
    );

    testWidgets(
      'Initial/loading state on public route remains on public route without bounce',
      (tester) async {
        mockAuthBloc = MockAuthBloc(const AuthLoading());
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.home,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byKey(const Key('login_screen')), findsNothing);
      },
    );

    testWidgets(
      'Redirect-loop prevention: unauthenticated on /login or authenticated on / does not loop',
      (tester) async {
        mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.login,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('login_screen')), findsOneWidget);

        // Tampered from param pointing to login itself does not cause loop when authenticated
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        appRouter.router.go('${AppRoutes.login}?from=${AppRoutes.login}');
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Intended-route preservation redirects authenticated user to original destination',
      (tester) async {
        mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
        appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.history,
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: appRouter.router,
          ),
        );
        await tester.pumpAndSettle();

        // Redirected to login with ?from=/history
        expect(find.byKey(const Key('login_screen')), findsOneWidget);

        // User authenticates
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        await tester.pumpAndSettle();

        // Arrives at preserved intended destination
        expect(find.byKey(const Key('history_screen')), findsOneWidget);
        expect(find.byKey(const Key('login_screen')), findsNothing);
      },
    );
  });
}

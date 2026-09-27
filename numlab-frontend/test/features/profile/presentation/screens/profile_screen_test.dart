import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/profile/presentation/profile_screen.dart';

class MockAuthBloc extends Fake implements AuthBloc {
  MockAuthBloc(this._initialState) {
    _state = _initialState;
  }

  final AuthState _initialState;
  late AuthState _state;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();
  final List<AuthEvent> recordedEvents = [];

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  void add(AuthEvent event) {
    recordedEvents.add(event);
  }

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
  late MockAuthBloc mockAuthBloc;

  final tUser = User(
    id: 'usr_7890_abcd',
    email: 'euler@numlab.ai',
    emailVerified: true,
    createdAt: DateTime.parse('2026-09-20T10:00:00.000Z'),
    lastLoginAt: DateTime.parse('2026-09-27T08:30:00.000Z'),
    updatedAt: DateTime.parse('2026-09-27T08:30:00.000Z'),
  );

  tearDown(() async {
    await mockAuthBloc.close();
  });

  Widget buildTestableProfileScreen({
    MockAuthBloc? bloc,
  }) {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: bloc ?? mockAuthBloc,
        child: const ProfileScreen(),
      ),
    );
  }

  group('ProfileScreen Widget Rendering & Actions', () {
    setUp(() {
      mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
    });

    testWidgets('renders all authenticated user details and action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableProfileScreen());

      expect(find.byKey(const Key('profile_screen')), findsOneWidget);
      expect(find.text('User Profile'), findsOneWidget);

      // Verify all domain user fields displayed
      expect(find.byKey(const Key('profile_user_id')), findsOneWidget);
      expect(find.text('ID: usr_7890_abcd'), findsOneWidget);

      expect(find.byKey(const Key('profile_user_email')), findsOneWidget);
      expect(find.text('Email: euler@numlab.ai'), findsOneWidget);

      expect(find.byKey(const Key('profile_user_verified')), findsOneWidget);
      expect(find.text('Verified: true'), findsOneWidget);

      expect(find.byKey(const Key('profile_created_at')), findsOneWidget);
      expect(
        find.text('Created: 2026-09-20T10:00:00.000Z'),
        findsOneWidget,
      );

      expect(find.byKey(const Key('profile_last_login_at')), findsOneWidget);
      expect(
        find.text('Last Login: 2026-09-27T08:30:00.000Z'),
        findsOneWidget,
      );

      expect(find.byKey(const Key('profile_updated_at')), findsOneWidget);
      expect(
        find.text('Updated: 2026-09-27T08:30:00.000Z'),
        findsOneWidget,
      );

      // Action buttons
      expect(find.byKey(const Key('profile_refresh_button')), findsOneWidget);
      expect(
        find.byKey(const Key('profile_refresh_icon_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profile_logout_button')), findsOneWidget);
      expect(
        find.byKey(const Key('profile_logout_all_button')),
        findsOneWidget,
      );
    });

    testWidgets('renders fallback placeholder for null optional timestamps', (
      tester,
    ) async {
      final userWithNullTimestamps = User(
        id: 'usr_new_9999',
        email: 'gauss@numlab.ai',
        emailVerified: false,
        createdAt: DateTime.parse('2026-09-27T09:00:00.000Z'),
      );

      mockAuthBloc = MockAuthBloc(
        AuthAuthenticated(user: userWithNullTimestamps),
      );
      await tester.pumpWidget(buildTestableProfileScreen());

      expect(find.text('Last Login: Never'), findsOneWidget);
      expect(find.text('Updated: Never'), findsOneWidget);
      expect(find.text('Verified: false'), findsOneWidget);
    });

    testWidgets(
      'tapping refresh button or AppBar icon dispatches AuthGetCurrentUserRequested',
      (tester) async {
        await tester.pumpWidget(buildTestableProfileScreen());

        // Tap main refresh button
        await tester.tap(find.byKey(const Key('profile_refresh_button')));
        await tester.pump();

        expect(
          mockAuthBloc.recordedEvents,
          contains(const AuthGetCurrentUserRequested()),
        );

        // Tap AppBar refresh icon button
        await tester.tap(find.byKey(const Key('profile_refresh_icon_button')));
        await tester.pump();

        expect(
          mockAuthBloc.recordedEvents
              .whereType<AuthGetCurrentUserRequested>()
              .length,
          equals(2),
        );
      },
    );

    testWidgets('tapping logout button dispatches AuthLogoutRequested', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableProfileScreen());

      await tester.tap(find.byKey(const Key('profile_logout_button')));
      await tester.pump();

      expect(
        mockAuthBloc.recordedEvents,
        contains(const AuthLogoutRequested()),
      );
    });

    testWidgets('tapping logout all button dispatches AuthLogoutAllRequested', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableProfileScreen());

      await tester.tap(find.byKey(const Key('profile_logout_all_button')));
      await tester.pump();

      expect(
        mockAuthBloc.recordedEvents,
        contains(const AuthLogoutAllRequested()),
      );
    });

    testWidgets('renders loading spinner when AuthLoading', (tester) async {
      mockAuthBloc = MockAuthBloc(const AuthLoading());
      await tester.pumpWidget(buildTestableProfileScreen());

      expect(
        find.byKey(const Key('profile_loading_indicator')),
        findsOneWidget,
      );
    });

    testWidgets('renders error banner and retry button when AuthError', (
      tester,
    ) async {
      mockAuthBloc = MockAuthBloc(
        const AuthError(
          failure: ServerFailure(
            message: 'Failed to synchronize user profile.',
          ),
        ),
      );
      await tester.pumpWidget(buildTestableProfileScreen());

      expect(find.byKey(const Key('auth_error_banner')), findsOneWidget);
      expect(
        find.text('Failed to synchronize user profile.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profile_retry_button')), findsOneWidget);

      // Tapping retry dispatches AuthGetCurrentUserRequested
      await tester.tap(find.byKey(const Key('profile_retry_button')));
      await tester.pump();

      expect(
        mockAuthBloc.recordedEvents,
        contains(const AuthGetCurrentUserRequested()),
      );
    });

    testWidgets('renders unauthenticated fallback when AuthUnauthenticated', (
      tester,
    ) async {
      mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
      await tester.pumpWidget(buildTestableProfileScreen());

      expect(
        find.byKey(const Key('profile_unauthenticated_text')),
        findsOneWidget,
      );
    });
  });

  group('Complete Auth Loop & Router Synchronization Integration Tests', () {
    late AppRouter appRouter;

    tearDown(() {
      appRouter.dispose();
    });

    testWidgets('Navigating from Authenticated Home to Profile Screen', (
      tester,
    ) async {
      mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
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

      expect(find.byKey(const Key('home_to_profile_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('home_to_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_screen')), findsOneWidget);
      expect(find.text('Email: euler@numlab.ai'), findsOneWidget);
    });

    testWidgets('Profile user refresh updates displayed profile data live', (
      tester,
    ) async {
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

      expect(find.text('Email: euler@numlab.ai'), findsOneWidget);

      // Tap refresh
      await tester.tap(find.byKey(const Key('profile_refresh_button')));
      await tester.pump();

      expect(
        mockAuthBloc.recordedEvents,
        contains(const AuthGetCurrentUserRequested()),
      );

      // Simulate updated user profile received from /users/me
      final updatedUser = User(
        id: 'usr_7890_abcd',
        email: 'euler.updated@numlab.ai',
        emailVerified: true,
        createdAt: DateTime.parse('2026-09-20T10:00:00.000Z'),
        lastLoginAt: DateTime.parse('2026-09-27T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-09-27T10:00:00.000Z'),
      );
      mockAuthBloc.emitState(AuthAuthenticated(user: updatedUser));
      await tester.pumpAndSettle();

      expect(find.text('Email: euler.updated@numlab.ai'), findsOneWidget);
      expect(
        find.text('Updated: 2026-09-27T10:00:00.000Z'),
        findsOneWidget,
      );
    });

    testWidgets('Logout from Profile triggers immediate redirect to Login', (
      tester,
    ) async {
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

      // User initiates logout from profile screen
      await tester.tap(find.byKey(const Key('profile_logout_button')));
      await tester.pump();

      expect(
        mockAuthBloc.recordedEvents,
        contains(const AuthLogoutRequested()),
      );

      // AuthBloc transitions to unauthenticated
      mockAuthBloc.emitState(const AuthUnauthenticated());
      await tester.pumpAndSettle();

      // Guard redirects immediately to login, preserving destination
      expect(find.byKey(const Key('profile_screen')), findsNothing);
      expect(find.byKey(const Key('login_screen')), findsOneWidget);

      final currentUri = appRouter.router.routeInformationProvider.value.uri;
      expect(currentUri.path, AppRoutes.login);
      expect(currentUri.queryParameters['from'], AppRoutes.profile);
    });

    testWidgets(
      'Logout-all from Profile triggers immediate redirect to Login',
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

        // User initiates logout-all from profile screen
        await tester.tap(find.byKey(const Key('profile_logout_all_button')));
        await tester.pump();

        expect(
          mockAuthBloc.recordedEvents,
          contains(const AuthLogoutAllRequested()),
        );

        // AuthBloc transitions to unauthenticated
        mockAuthBloc.emitState(const AuthUnauthenticated());
        await tester.pumpAndSettle();

        // Guard redirects immediately to login
        expect(find.byKey(const Key('profile_screen')), findsNothing);
        expect(find.byKey(const Key('login_screen')), findsOneWidget);

        final currentUri = appRouter.router.routeInformationProvider.value.uri;
        expect(currentUri.path, AppRoutes.login);
        expect(currentUri.queryParameters['from'], AppRoutes.profile);
      },
    );

    testWidgets(
      'Session revocation from interceptor while on Profile redirects to Login',
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

        // Simulate token revocation triggered by 401 refresh failure in DioClient
        mockAuthBloc.emitState(const AuthUnauthenticated());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsNothing);
        expect(find.byKey(const Key('login_screen')), findsOneWidget);
      },
    );

    testWidgets(
      'Session restoration allows direct access to Profile after app launch',
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
        // During initialization, router does not prematurely redirect
        await tester.pump();
        expect(find.byKey(const Key('login_screen')), findsNothing);

        // Restoration checks storage and network
        mockAuthBloc.emitState(const AuthLoading());
        await tester.pump();
        expect(find.byKey(const Key('login_screen')), findsNothing);

        // Session restored successfully
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsOneWidget);
        expect(find.text('Email: euler@numlab.ai'), findsOneWidget);
      },
    );

    testWidgets('Background token refresh keeps user authenticated on Profile', (
      tester,
    ) async {
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

      // Token rotation occurs behind the scenes; AuthBloc re-emits active user
      mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
      await tester.pumpAndSettle();

      // Session remains stable without flicker or navigation bounce
      expect(find.byKey(const Key('profile_screen')), findsOneWidget);
      expect(find.byKey(const Key('login_screen')), findsNothing);
    });

    testWidgets(
      'Complete auth loop: Login -> Home -> Profile -> Refresh -> Logout -> Login',
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

        // 1. On Login Screen
        expect(find.byKey(const Key('login_screen')), findsOneWidget);

        // 2. User submits credentials and logs in
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        await tester.pumpAndSettle();

        // 3. Router guard redirects to Home
        expect(find.byKey(const Key('login_screen')), findsNothing);
        expect(
          find.byKey(const Key('authenticated_user_card')),
          findsOneWidget,
        );

        // 4. Navigate from Home to Profile
        await tester.tap(find.byKey(const Key('home_to_profile_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsOneWidget);
        expect(find.text('Email: euler@numlab.ai'), findsOneWidget);

        // 5. Refresh current user on Profile
        await tester.tap(find.byKey(const Key('profile_refresh_button')));
        await tester.pump();
        expect(
          mockAuthBloc.recordedEvents,
          contains(const AuthGetCurrentUserRequested()),
        );

        // 6. User logs out from Profile
        await tester.tap(find.byKey(const Key('profile_logout_button')));
        await tester.pump();
        expect(
          mockAuthBloc.recordedEvents,
          contains(const AuthLogoutRequested()),
        );

        // 7. AuthBloc emits unauthenticated -> Router redirects to Login
        mockAuthBloc.emitState(const AuthUnauthenticated());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsNothing);
        expect(find.byKey(const Key('login_screen')), findsOneWidget);
      },
    );
  });
}

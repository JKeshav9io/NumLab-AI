import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/auth/presentation/screens/screens.dart';
import 'package:numlab_frontend/features/placeholder/presentation/placeholder_home_screen.dart';

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
    id: 'user-uuid-1234',
    email: 'scholar@numlab.ai',
    emailVerified: true,
    createdAt: DateTime.parse('2026-09-26T12:00:00.000Z'),
  );

  tearDown(() async {
    await mockAuthBloc.close();
  });

  Widget buildTestableScreen({
    required Widget child,
    MockAuthBloc? bloc,
  }) {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: bloc ?? mockAuthBloc,
        child: child,
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    setUp(() {
      mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
    });

    testWidgets('renders all minimal login components', (tester) async {
      await tester.pumpWidget(buildTestableScreen(child: const LoginScreen()));

      expect(find.byKey(const Key('login_screen')), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('login_to_register_button')), findsOneWidget);
      expect(find.text('Login'), findsWidgets);
    });

    testWidgets('shows validation errors when fields are empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen(child: const LoginScreen()));

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      expect(mockAuthBloc.recordedEvents, isEmpty);
    });

    testWidgets(
      'dispatches AuthLoginRequested when form is submitted with valid inputs',
      (tester) async {
        await tester.pumpWidget(
          buildTestableScreen(child: const LoginScreen()),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_field')),
          'scholar@numlab.ai',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'Secr3t!P@ss',
        );

        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pump();

        expect(
          mockAuthBloc.recordedEvents,
          contains(
            const AuthLoginRequested(
              email: 'scholar@numlab.ai',
              password: 'Secr3t!P@ss',
            ),
          ),
        );
      },
    );

    testWidgets(
      'renders loading state and disables submit button when AuthLoading',
      (tester) async {
        mockAuthBloc = MockAuthBloc(const AuthLoading());
        await tester.pumpWidget(
          buildTestableScreen(child: const LoginScreen()),
        );

        expect(
          find.byKey(const Key('login_loading_indicator')),
          findsOneWidget,
        );

        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('login_submit_button')),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('renders error banner with message when AuthError', (
      tester,
    ) async {
      mockAuthBloc = MockAuthBloc(
        const AuthError(
          failure: AuthFailure(
            message: 'Invalid credentials. Please try again.',
          ),
        ),
      );
      await tester.pumpWidget(buildTestableScreen(child: const LoginScreen()));

      expect(find.byKey(const Key('auth_error_banner')), findsOneWidget);
      expect(
        find.text('Invalid credentials. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('RegisterScreen Widget Tests', () {
    setUp(() {
      mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
    });

    testWidgets('renders all minimal register components', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(child: const RegisterScreen()),
      );

      expect(find.byKey(const Key('register_screen')), findsOneWidget);
      expect(find.byKey(const Key('register_email_field')), findsOneWidget);
      expect(find.byKey(const Key('register_password_field')), findsOneWidget);
      expect(find.byKey(const Key('register_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('register_to_login_button')), findsOneWidget);
      expect(find.text('Register'), findsWidgets);
    });

    testWidgets('shows validation errors when fields are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableScreen(child: const RegisterScreen()),
      );

      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      expect(mockAuthBloc.recordedEvents, isEmpty);
    });

    testWidgets(
      'dispatches AuthRegisterRequested when form is submitted with valid inputs',
      (tester) async {
        await tester.pumpWidget(
          buildTestableScreen(child: const RegisterScreen()),
        );

        await tester.enterText(
          find.byKey(const Key('register_email_field')),
          'newuser@numlab.ai',
        );
        await tester.enterText(
          find.byKey(const Key('register_password_field')),
          'ComplexPass123!',
        );

        await tester.tap(find.byKey(const Key('register_submit_button')));
        await tester.pump();

        expect(
          mockAuthBloc.recordedEvents,
          contains(
            const AuthRegisterRequested(
              email: 'newuser@numlab.ai',
              password: 'ComplexPass123!',
            ),
          ),
        );
      },
    );

    testWidgets(
      'renders loading state and disables submit button when AuthLoading',
      (tester) async {
        mockAuthBloc = MockAuthBloc(const AuthLoading());
        await tester.pumpWidget(
          buildTestableScreen(child: const RegisterScreen()),
        );

        expect(
          find.byKey(const Key('register_loading_indicator')),
          findsOneWidget,
        );

        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('register_submit_button')),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('renders error banner with message when AuthError', (
      tester,
    ) async {
      mockAuthBloc = MockAuthBloc(
        const AuthError(
          failure: AuthFailure(message: 'Email is already registered.'),
        ),
      );
      await tester.pumpWidget(
        buildTestableScreen(child: const RegisterScreen()),
      );

      expect(find.byKey(const Key('auth_error_banner')), findsOneWidget);
      expect(find.text('Email is already registered.'), findsOneWidget);
    });
  });

  group('AuthLoadingScreen Widget Tests', () {
    testWidgets('renders loading spinner and restoration message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuthLoadingScreen(),
        ),
      );

      expect(find.byKey(const Key('auth_loading_screen')), findsOneWidget);
      expect(find.byKey(const Key('auth_loading_indicator')), findsOneWidget);
      expect(find.byKey(const Key('auth_loading_message')), findsOneWidget);
      expect(find.text('Restoring session...'), findsOneWidget);
    });
  });

  group('Authenticated Home Screen Widget Tests', () {
    setUp(() {
      mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
    });

    testWidgets('renders authenticated user details and logout button', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableScreen(child: const PlaceholderHomeScreen()),
      );

      expect(find.byKey(const Key('authenticated_user_card')), findsOneWidget);
      expect(find.byKey(const Key('user_id_display')), findsOneWidget);
      expect(find.text('ID: user-uuid-1234'), findsOneWidget);
      expect(find.byKey(const Key('user_email_display')), findsOneWidget);
      expect(find.text('Email: scholar@numlab.ai'), findsOneWidget);
      expect(find.byKey(const Key('user_verified_display')), findsOneWidget);
      expect(find.text('Verified: true'), findsOneWidget);
      expect(find.byKey(const Key('logout_button')), findsOneWidget);
    });

    testWidgets('tapping logout button dispatches AuthLogoutRequested', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableScreen(child: const PlaceholderHomeScreen()),
      );

      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pump();

      expect(
        mockAuthBloc.recordedEvents,
        contains(const AuthLogoutRequested()),
      );
    });
  });

  group('End-to-End Routing & Navigation Integration Tests', () {
    late AppRouter appRouter;

    tearDown(() {
      appRouter.dispose();
    });

    testWidgets('Navigating from Login to Register via text button', (
      tester,
    ) async {
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

      await tester.tap(find.byKey(const Key('login_to_register_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register_screen')), findsOneWidget);
    });

    testWidgets('Navigating from Register to Login via text button', (
      tester,
    ) async {
      mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
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

      expect(find.byKey(const Key('register_screen')), findsOneWidget);

      await tester.tap(find.byKey(const Key('register_to_login_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_screen')), findsOneWidget);
    });

    testWidgets(
      'Login success redirects via router guard to Authenticated Home',
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

        // Simulate successful login event emitted by AuthBloc
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        await tester.pumpAndSettle();

        // Router guard redirects from /login to /
        expect(find.byKey(const Key('login_screen')), findsNothing);
        expect(
          find.byKey(const Key('authenticated_user_card')),
          findsOneWidget,
        );
        expect(find.text('Email: scholar@numlab.ai'), findsOneWidget);
      },
    );

    testWidgets(
      'Register success redirects via router guard to Authenticated Home',
      (tester) async {
        mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
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

        expect(find.byKey(const Key('register_screen')), findsOneWidget);

        // Simulate successful register event emitted by AuthBloc
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        await tester.pumpAndSettle();

        // Router guard redirects from /register to /
        expect(find.byKey(const Key('register_screen')), findsNothing);
        expect(
          find.byKey(const Key('authenticated_user_card')),
          findsOneWidget,
        );
        expect(find.text('Email: scholar@numlab.ai'), findsOneWidget);
      },
    );

    testWidgets(
      'Logout transitions Authenticated Home to Unauthenticated view',
      (tester) async {
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

        expect(
          find.byKey(const Key('authenticated_user_card')),
          findsOneWidget,
        );

        // User taps logout
        await tester.tap(find.byKey(const Key('logout_button')));
        await tester.pump();

        expect(
          mockAuthBloc.recordedEvents,
          contains(const AuthLogoutRequested()),
        );

        // Bloc responds by emitting AuthUnauthenticated
        mockAuthBloc.emitState(const AuthUnauthenticated());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('authenticated_user_card')), findsNothing);
        expect(
          find.byKey(const Key('unauthenticated_session_card')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('home_login_button')), findsOneWidget);
        expect(find.byKey(const Key('home_register_button')), findsOneWidget);
      },
    );

    testWidgets(
      'Session restoration on launch transitions into Authenticated view',
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

        // Verifies session restoring state
        expect(find.byKey(const Key('auth_loading_card')), findsOneWidget);
        expect(find.text('Restoring session...'), findsOneWidget);

        // Session restored successfully
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('auth_loading_card')), findsNothing);
        expect(
          find.byKey(const Key('authenticated_user_card')),
          findsOneWidget,
        );
        expect(find.text('Email: scholar@numlab.ai'), findsOneWidget);
      },
    );
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/presentation/screens/screens.dart';

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
    id: 'user-007',
    email: 'gauss@numlab.ai',
    emailVerified: true,
    createdAt: DateTime.parse('2026-09-28T12:00:00.000Z'),
  );

  tearDown(() async {
    await mockAuthBloc.close();
  });

  Widget buildHomeScreen({MockAuthBloc? authBloc}) {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: authBloc ?? mockAuthBloc,
        child: const HomeScreen(),
      ),
    );
  }

  group('HomeScreen Category Navigation Tests', () {
    setUp(() {
      mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
    });

    testWidgets('loads all 6 registered category cards with correct method counts', (
      tester,
    ) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Numerical Solver Workspaces'), findsOneWidget);
      expect(find.text('Categories (6)'), findsOneWidget);

      for (final category in SolverCategory.values) {
        expect(
          find.byKey(Key('category_card_${category.id}')),
          findsOneWidget,
        );
        expect(find.text(category.displayName), findsOneWidget);
        final count = SolverMethodRegistry.getByCategory(category).length;
        final badge = find.byKey(Key('category_methods_badge_${category.id}'));
        expect(badge, findsOneWidget);
        final badgeWidget = tester.widget<Text>(badge);
        expect(badgeWidget.data, equals('$count methods'));
      }
    });

    testWidgets('each category card has correct title, description, and badge', (
      tester,
    ) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      for (final category in SolverCategory.values) {
        final cardFinder = find.byKey(Key('category_card_${category.id}'));
        await tester.ensureVisible(cardFinder);

        expect(find.byKey(Key('category_title_${category.id}')), findsOneWidget);
        expect(find.byKey(Key('category_desc_${category.id}')), findsOneWidget);
        expect(
          find.byKey(Key('category_methods_badge_${category.id}')),
          findsOneWidget,
        );
      }
    });
  });

  group('HomeScreen Authentication & User State Display Tests', () {
    testWidgets(
      'renders guest session banner with login/register buttons when unauthenticated',
      (
        tester,
      ) async {
        mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('unauthenticated_session_card')),
          findsOneWidget,
        );
        expect(find.text('Guest Session'), findsOneWidget);
        expect(find.byKey(const Key('home_login_button')), findsOneWidget);
        expect(find.byKey(const Key('home_register_button')), findsOneWidget);
        expect(find.byKey(const Key('authenticated_user_card')), findsNothing);
        expect(find.byKey(const Key('appbar_profile_button')), findsNothing);
      },
    );

    testWidgets(
      'renders authenticated card with user details and profile/logout buttons',
      (
        tester,
      ) async {
        mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('authenticated_user_card')),
          findsOneWidget,
        );
        expect(find.text('ID: user-007'), findsOneWidget);
        expect(find.text('Email: gauss@numlab.ai'), findsOneWidget);
        expect(find.text('Verified: true'), findsOneWidget);
        expect(find.byKey(const Key('home_to_profile_button')), findsOneWidget);
        expect(find.byKey(const Key('logout_button')), findsOneWidget);
        expect(find.byKey(const Key('appbar_profile_button')), findsOneWidget);
        expect(
          find.byKey(const Key('unauthenticated_session_card')),
          findsNothing,
        );
      },
    );

    testWidgets('tapping logout dispatches AuthLogoutRequested', (
      tester,
    ) async {
      mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pump();

      expect(
        mockAuthBloc.recordedEvents,
        contains(const AuthLogoutRequested()),
      );
    });

    testWidgets('renders restoring session banner when AuthLoading', (
      tester,
    ) async {
      mockAuthBloc = MockAuthBloc(const AuthLoading());
      await tester.pumpWidget(buildHomeScreen());

      expect(find.byKey(const Key('auth_loading_card')), findsOneWidget);
      expect(find.text('Restoring session...'), findsOneWidget);
    });

    testWidgets(
      'dynamic auth state transition updates Home screen banner live',
      (
        tester,
      ) async {
        mockAuthBloc = MockAuthBloc(const AuthLoading());
        await tester.pumpWidget(buildHomeScreen());

        expect(find.byKey(const Key('auth_loading_card')), findsOneWidget);

        // Transitions to Authenticated
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('auth_loading_card')), findsNothing);
        expect(
          find.byKey(const Key('authenticated_user_card')),
          findsOneWidget,
        );

        // Transitions to Unauthenticated
        mockAuthBloc.emitState(const AuthUnauthenticated());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('authenticated_user_card')), findsNothing);
        expect(
          find.byKey(const Key('unauthenticated_session_card')),
          findsOneWidget,
        );
      },
    );
  });

  group('HomeScreen Category Selection & Navigation Integration Tests', () {
    testWidgets('tapping category card navigates to /workspace/:categoryId route', (
      tester,
    ) async {
      mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => BlocProvider<AuthBloc>.value(
              value: mockAuthBloc,
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '${AppRoutes.workspacePrefix}/:categoryId',
            builder: (context, state) {
              pushedRoute = state.uri.toString();
              return Scaffold(
                body: Text(
                  'Workspace: ${state.pathParameters['categoryId']}',
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Tap on Root Finding Category Card
      final rootCard = find.byKey(
        Key('category_card_${SolverCategory.rootFinding.id}'),
      );
      expect(rootCard, findsOneWidget);
      await tester.tap(rootCard);
      await tester.pumpAndSettle();

      expect(pushedRoute, equals('/workspace/root-finding'));
      expect(find.text('Workspace: root-finding'), findsOneWidget);
    });

    testWidgets(
      'all 6 solver categories can be tapped and reach their workspace route',
      (
        tester,
      ) async {
        mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());

        final visitedCategories = <String>[];
        final router = GoRouter(
          initialLocation: AppRoutes.home,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => BlocProvider<AuthBloc>.value(
                value: mockAuthBloc,
                child: const HomeScreen(),
              ),
            ),
            GoRoute(
              path: '${AppRoutes.workspacePrefix}/:categoryId',
              builder: (context, state) {
                final id = state.pathParameters['categoryId']!;
                visitedCategories.add(id);
                return Scaffold(body: Text('Workspace: $id'));
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        for (final category in SolverCategory.values) {
          final card = find.byKey(Key('category_card_${category.id}'));
          await tester.ensureVisible(card);
          await tester.tap(card);
          await tester.pumpAndSettle();

          expect(find.text('Workspace: ${category.id}'), findsOneWidget);

          // Navigate back to home (context.go replaces the stack, so use go not pop)
          router.go(AppRoutes.home);
          await tester.pumpAndSettle();
        }

        expect(visitedCategories.length, equals(6));
        expect(
          visitedCategories,
          containsAll(SolverCategory.values.map((c) => c.id)),
        );
      },
    );
  });
}

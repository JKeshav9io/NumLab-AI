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

  group('HomeScreen Category & Solver Listing Tests', () {
    setUp(() {
      mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
    });

    testWidgets('loads all 6 registered categories and All chip', (
      tester,
    ) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category_chip_all')), findsOneWidget);
      expect(find.text('All (27)'), findsOneWidget);

      for (final category in SolverCategory.values) {
        expect(
          find.byKey(Key('category_chip_${category.id}')),
          findsOneWidget,
        );
        final count = SolverMethodRegistry.getByCategory(category).length;
        expect(find.text('${category.displayName} ($count)'), findsOneWidget);
      }
    });

    testWidgets(
      'displays all 27 solvers from SolverMethodRegistry by default',
      (
        tester,
      ) async {
        await tester.pumpWidget(buildHomeScreen());
        await tester.pumpAndSettle();

        expect(find.text('All Solvers (27)'), findsOneWidget);

        // Verify all 27 registered solvers are in the registry and displayed
        expect(SolverMethodRegistry.all.length, equals(27));
        for (final solver in SolverMethodRegistry.all) {
          expect(find.byKey(Key('solver_card_${solver.id}')), findsOneWidget);
          expect(find.text(solver.name), findsOneWidget);
        }
      },
    );

    testWidgets('filters solvers accurately across each individual category', (
      tester,
    ) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      for (final category in SolverCategory.values) {
        final categoryChipFinder = find.byKey(
          Key('category_chip_${category.id}'),
        );
        await tester.ensureVisible(categoryChipFinder);
        await tester.tap(categoryChipFinder);
        await tester.pumpAndSettle();

        final expectedSolvers = SolverMethodRegistry.getByCategory(category);
        expect(
          tester.widget<Text>(find.byKey(const Key('solvers_count_text'))).data,
          equals('${category.displayName} (${expectedSolvers.length})'),
        );

        // Expected solvers in this category must be present
        for (final solver in expectedSolvers) {
          expect(find.byKey(Key('solver_card_${solver.id}')), findsOneWidget);
        }

        // Solvers in other categories must NOT be present
        for (final otherSolver in SolverMethodRegistry.all) {
          if (otherSolver.category != category) {
            expect(
              find.byKey(Key('solver_card_${otherSolver.id}')),
              findsNothing,
            );
          }
        }
      }
    });

    testWidgets('clearing category filter restores all 27 solvers', (
      tester,
    ) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      // Select root finding category (4 solvers)
      final rootChip = find.byKey(
        Key('category_chip_${SolverCategory.rootFinding.id}'),
      );
      await tester.ensureVisible(rootChip);
      await tester.tap(rootChip);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('solvers_count_text'))).data,
        equals('${SolverCategory.rootFinding.displayName} (4)'),
      );

      // Tap 'Show All' clear button
      expect(find.byKey(const Key('clear_filter_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('clear_filter_button')));
      await tester.pumpAndSettle();

      // Restored to all 27
      expect(
        tester.widget<Text>(find.byKey(const Key('solvers_count_text'))).data,
        equals('All Solvers (27)'),
      );
      for (final solver in SolverMethodRegistry.all) {
        expect(find.byKey(Key('solver_card_${solver.id}')), findsOneWidget);
      }
    });

    testWidgets('tapping All chip resets any active category filter', (
      tester,
    ) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      // Select ODE category
      final odeChip = find.byKey(
        Key('category_chip_${SolverCategory.ode.id}'),
      );
      await tester.ensureVisible(odeChip);
      await tester.tap(odeChip);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('solvers_count_text'))).data,
        equals('${SolverCategory.ode.displayName} (4)'),
      );

      // Tap 'All (27)' chip
      final allChip = find.byKey(const Key('category_chip_all'));
      await tester.ensureVisible(allChip);
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('solvers_count_text'))).data,
        equals('All Solvers (27)'),
      );
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

  group('HomeScreen Solver Selection & Navigation Integration Tests', () {
    testWidgets('tapping solver card navigates to /solver/:solverId route', (
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
            path: '${AppRoutes.solverPrefix}/:solverId',
            builder: (context, state) {
              pushedRoute = state.uri.toString();
              return Scaffold(
                body: Text(
                  'Solver Screen: ${state.pathParameters['solverId']}',
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Tap on Bisection Method
      final bisectionCard = find.byKey(const Key('solver_card_bisection'));
      expect(bisectionCard, findsOneWidget);
      await tester.tap(bisectionCard);
      await tester.pumpAndSettle();

      expect(pushedRoute, equals('/solver/bisection'));
      expect(find.text('Solver Screen: bisection'), findsOneWidget);
    });

    testWidgets(
      'all 27 numerical solvers can be tapped and reach their solver route',
      (
        tester,
      ) async {
        mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());

        final visitedSolvers = <String>[];
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
              path: '${AppRoutes.solverPrefix}/:solverId',
              builder: (context, state) {
                final id = state.pathParameters['solverId']!;
                visitedSolvers.add(id);
                return Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  body: Text('Solver: $id'),
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        for (final solver in SolverMethodRegistry.all) {
          final card = find.byKey(Key('solver_card_${solver.id}'));
          await tester.ensureVisible(card);
          await tester.tap(card);
          await tester.pumpAndSettle();

          expect(find.text('Solver: ${solver.id}'), findsOneWidget);

          // Pop back to home
          await tester.tap(find.byType(IconButton).first);
          await tester.pumpAndSettle();
        }

        expect(visitedSolvers.length, equals(27));
        expect(
          visitedSolvers,
          containsAll(SolverMethodRegistry.all.map((s) => s.id)),
        );
      },
    );
  });
}

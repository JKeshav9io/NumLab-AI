import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/entities.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/presentation/screens/screens.dart';

class MockExecuteSolverUseCase extends Fake implements ExecuteSolverUseCase {
  FutureOr<Either<Failure, SolverResult>> Function({
    required String solverId,
    required Map<String, dynamic> payload,
    String? accessToken,
  })?
  onCall;

  @override
  Future<Either<Failure, SolverResult>> call({
    required String solverId,
    required Map<String, dynamic> payload,
    String? accessToken,
  }) {
    if (onCall != null) {
      final res = onCall!(
        solverId: solverId,
        payload: payload,
        accessToken: accessToken,
      );
      if (res is Future<Either<Failure, SolverResult>>) {
        return res;
      }
      return SynchronousFuture(res);
    }
    return SynchronousFuture(
      Right(
        SolverResult(
          method: solverId,
          finalAnswer: const {'status': 'success'},
        ),
      ),
    );
  }
}

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

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  group('1. Registry and Category Integrity Verification', () {
    test('registry contains exactly 27 numerical solver methods', () {
      expect(SolverMethodRegistry.all.length, equals(27));
    });

    test('each of the 27 methods belongs to exactly one of the 6 categories', () {
      final categoryCounts = <SolverCategory, int>{};
      for (final category in SolverCategory.values) {
        categoryCounts[category] = 0;
      }

      for (final method in SolverMethodRegistry.all) {
        expect(SolverCategory.values.contains(method.category), isTrue);
        categoryCounts[method.category] = categoryCounts[method.category]! + 1;
      }

      // Assert expected counts per mathematical category
      expect(categoryCounts[SolverCategory.rootFinding], equals(4));
      expect(categoryCounts[SolverCategory.linearAlgebra], equals(3));
      expect(categoryCounts[SolverCategory.interpolation], equals(7));
      expect(categoryCounts[SolverCategory.ode], equals(4));
      expect(categoryCounts[SolverCategory.integration], equals(4));
      expect(categoryCounts[SolverCategory.differentiation], equals(5));

      final total = categoryCounts.values.reduce((a, b) => a + b);
      expect(total, equals(27));
    });

    test('every method is reachable from its category resolution', () {
      for (final category in SolverCategory.values) {
        final methods = SolverMethodRegistry.getByCategory(category);
        expect(methods.isNotEmpty, isTrue);
        for (final m in methods) {
          expect(m.category, equals(category));
          expect(SolverMethodRegistry.getById(m.id), equals(m));
        }
      }
    });
  });

  group('2. Category Workspace Responsive Selector & Switching Tests', () {
    late MockExecuteSolverUseCase mockExecuteSolverUseCase;
    late SolverFormBloc solverFormBloc;

    setUp(() {
      mockExecuteSolverUseCase = MockExecuteSolverUseCase();
    });

    tearDown(() async {
      await solverFormBloc.close();
    });

    Widget buildWorkspace({
      required String categoryId,
      String? initialMethodId,
      Size screenSize = const Size(800, 900),
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: BlocProvider<SolverFormBloc>.value(
            value: solverFormBloc,
            child: SolverWorkspaceScreen(
              categoryId: categoryId,
              initialMethodId: initialMethodId,
            ),
          ),
        ),
      );
    }

    testWidgets('renders wide selector with choice chips on wide screen (>= 600px)', (
      tester,
    ) async {
      solverFormBloc = SolverFormBloc(
        executeSolverUseCase: mockExecuteSolverUseCase,
      );
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWorkspace(
          categoryId: 'root-finding',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('solver_workspace_screen')), findsOneWidget);
      expect(find.byKey(const Key('category_workspace_title')), findsOneWidget);
      expect(find.text('Root Finding'), findsWidgets);
      expect(find.byKey(const Key('method_selector_wide')), findsOneWidget);
      expect(find.byKey(const Key('method_selector_compact')), findsNothing);

      // Verify all Root Finding methods are rendered as chips
      final methods = SolverMethodRegistry.getByCategory(SolverCategory.rootFinding);
      for (final m in methods) {
        expect(find.byKey(Key('method_chip_${m.id}')), findsOneWidget);
      }

      // Default active method is the first one (Bisection Method)
      expect(find.text('Active Method: Bisection Method'), findsOneWidget);
    });

    testWidgets('renders compact dropdown selector on narrow screen (< 600px)', (
      tester,
    ) async {
      solverFormBloc = SolverFormBloc(
        executeSolverUseCase: mockExecuteSolverUseCase,
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWorkspace(
          categoryId: 'root-finding',
          screenSize: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('method_selector_compact')), findsOneWidget);
      expect(find.byKey(const Key('method_selector_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('method_selector_wide')), findsNothing);
    });

    testWidgets('selecting a different method in wide layout switches active method', (
      tester,
    ) async {
      solverFormBloc = SolverFormBloc(
        executeSolverUseCase: mockExecuteSolverUseCase,
      );
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWorkspace(
          categoryId: 'root-finding',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Method: Bisection Method'), findsOneWidget);

      // Tap Newton-Raphson chip
      final nrChip = find.byKey(const Key('method_chip_newton-raphson'));
      await tester.ensureVisible(nrChip);
      await tester.tap(nrChip);
      await tester.pumpAndSettle();

      expect(find.text('Active Method: Newton-Raphson Method'), findsOneWidget);
      expect(solverFormBloc.state.config?.id, equals('newton-raphson'));
    });

    testWidgets('unknown category displays error message and return button', (
      tester,
    ) async {
      solverFormBloc = SolverFormBloc(
        executeSolverUseCase: mockExecuteSolverUseCase,
      );
      await tester.pumpWidget(
        buildWorkspace(categoryId: 'non-existent-category'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workspace_error_message')), findsOneWidget);
      expect(find.text('Unknown or empty category: "non-existent-category"'), findsOneWidget);
      expect(find.byKey(const Key('workspace_go_home_button')), findsOneWidget);
    });
  });

  group('3. Full Flow Structural Verification (All 6 Categories)', () {
    late MockExecuteSolverUseCase mockExecuteSolverUseCase;
    late SolverFormBloc solverFormBloc;

    setUp(() {
      mockExecuteSolverUseCase = MockExecuteSolverUseCase();
    });

    tearDown(() async {
      await solverFormBloc.close();
    });

    Widget buildFlowApp({required String initialLocation}) {
      final mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '${AppRoutes.workspacePrefix}/:categoryId',
            builder: (context, state) {
              final categoryId = state.pathParameters['categoryId'] ?? '';
              final methodId = state.uri.queryParameters['method'];
              return SolverWorkspaceScreen(
                categoryId: categoryId,
                initialMethodId: methodId,
              );
            },
          ),
          GoRoute(
            path: '${AppRoutes.solverPrefix}/:solverId',
            redirect: (context, state) {
              final solverId = state.pathParameters['solverId'] ?? '';
              final config = SolverMethodRegistry.getById(solverId);
              if (config != null) {
                return AppRoutes.workspace(config.category.id, config.id);
              }
              return AppRoutes.home;
            },
          ),
        ],
      );

      return MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          BlocProvider<SolverFormBloc>.value(value: solverFormBloc),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets(
      'Flow 1: Root Finding (Bisection) Home → Category → Workspace → Solve → Result & Curve Graph',
      (tester) async {
        solverFormBloc = SolverFormBloc(
          executeSolverUseCase: mockExecuteSolverUseCase,
        );
        String? capturedSolverId;
        Map<String, dynamic>? capturedPayload;

        mockExecuteSolverUseCase.onCall = ({required solverId, required payload, accessToken}) {
          capturedSolverId = solverId;
          capturedPayload = payload;
          return const Right(
            SolverResult(
              method: 'bisection',
              status: 'converged',
              finalAnswer: {'root': 1.521},
              graphData: <Map<String, dynamic>>[
                {'x': 1.0, 'y': -2.0},
                {'x': 1.5, 'y': 0.0},
                {'x': 2.0, 'y': 4.0},
              ],
            ),
          );
        };

        await tester.pumpWidget(buildFlowApp(initialLocation: AppRoutes.home));
        await tester.pumpAndSettle();

        // 1. Home screen shows Root Finding category
        final rootCard = find.byKey(Key('category_card_${SolverCategory.rootFinding.id}'));
        expect(rootCard, findsOneWidget);
        await tester.tap(rootCard);
        await tester.pumpAndSettle();

        // 2. Navigated to Workspace
        expect(find.byKey(const Key('solver_workspace_screen')), findsOneWidget);
        expect(find.text('Active Method: Bisection Method'), findsOneWidget);

        // Fill required fields
        solverFormBloc.add(
          const SolverFormFieldsBulkChanged({
            'equation': 'x^3 - x - 2',
            'lowerBound': 1.0,
            'upperBound': 2.0,
          }),
        );
        await tester.pumpAndSettle();

        // 3. Execute Solve
        final submitButton = find.byKey(const Key('solver_submit_button'));
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // 4. Assert captured execution
        expect(capturedSolverId, equals('bisection'));
        expect(capturedPayload?['equation'], equals('x^3 - x - 2'));

        // 5. Result and Graph verified
        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
        expect(find.byKey(const Key('curve_chart_repaint_boundary')), findsOneWidget);
        expect(find.text('bisection Graph'), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 2: Linear Algebra (Gauss Elimination) Home → Category → Workspace → Solve → Result',
      (tester) async {
        solverFormBloc = SolverFormBloc(
          executeSolverUseCase: mockExecuteSolverUseCase,
        );
        String? capturedSolverId;

        mockExecuteSolverUseCase.onCall = ({required solverId, required payload, accessToken}) async {
          capturedSolverId = solverId;
          return const Right(
            SolverResult(
              method: 'gauss-elimination',
              status: 'converged',
              finalAnswer: {'solution': [1.0, 2.0]},
            ),
          );
        };

        await tester.pumpWidget(
          buildFlowApp(initialLocation: AppRoutes.workspace('linear-algebra', 'gauss-elimination')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Active Method: Gauss Elimination'), findsOneWidget);

        solverFormBloc.add(
          const SolverFormFieldsBulkChanged({
            'matrix': [
              [2.0, 1.0],
              [5.0, 7.0],
            ],
            'constants': [11.0, 13.0],
          }),
        );
        await tester.pumpAndSettle();

        final submitButton = find.byKey(const Key('solver_submit_button'));
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(capturedSolverId, equals('gauss-elimination'));
        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 3: Interpolation (Lagrange) Home → Category → Workspace → Solve → Result & Interpolation Chart',
      (tester) async {
        solverFormBloc = SolverFormBloc(
          executeSolverUseCase: mockExecuteSolverUseCase,
        );
        String? capturedSolverId;

        mockExecuteSolverUseCase.onCall = ({required solverId, required payload, accessToken}) async {
          capturedSolverId = solverId;
          return const Right(
            SolverResult(
              method: 'lagrange',
              status: 'converged',
              finalAnswer: {'predictedY': 4.5},
              graphData: <String, dynamic>{
                'originalPoints': <Map<String, dynamic>>[
                  {'x': 1, 'y': 2},
                  {'x': 3, 'y': 8},
                ],
                'sampledCurve': <Map<String, dynamic>>[
                  {'x': 1, 'y': 2},
                  {'x': 2, 'y': 4.5},
                  {'x': 3, 'y': 8},
                ],
                'predictedPoint': {'x': 2, 'y': 4.5},
              },
            ),
          );
        };

        await tester.pumpWidget(
          buildFlowApp(initialLocation: AppRoutes.workspace('interpolation', 'lagrange')),
        );
        await tester.pumpAndSettle();

        solverFormBloc.add(
          const SolverFormFieldsBulkChanged({
            'points': [
              {'x': 1.0, 'y': 2.0},
              {'x': 3.0, 'y': 8.0},
            ],
            'targetX': 2.0,
          }),
        );
        await tester.pumpAndSettle();

        final submitButton = find.byKey(const Key('solver_submit_button'));
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(capturedSolverId, equals('lagrange'));
        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
        expect(find.byKey(const Key('interpolation_chart_repaint_boundary')), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 4: ODE (Euler) Home → Category → Workspace → Solve → Result & Curve Graph',
      (tester) async {
        solverFormBloc = SolverFormBloc(
          executeSolverUseCase: mockExecuteSolverUseCase,
        );
        String? capturedSolverId;

        mockExecuteSolverUseCase.onCall = ({required solverId, required payload, accessToken}) async {
          capturedSolverId = solverId;
          return const Right(
            SolverResult(
              method: 'euler',
              status: 'converged',
              finalAnswer: {'y_end': 2.488},
              graphData: <Map<String, dynamic>>[
                {'x': 0.0, 'y': 1.0},
                {'x': 0.5, 'y': 1.5},
                {'x': 1.0, 'y': 2.488},
              ],
            ),
          );
        };

        await tester.pumpWidget(
          buildFlowApp(initialLocation: AppRoutes.workspace('ode', 'euler')),
        );
        await tester.pumpAndSettle();

        solverFormBloc.add(
          const SolverFormFieldsBulkChanged({
            'equation': 'x + y',
            'x0': 0.0,
            'y0': 1.0,
            'h': 0.1,
            'xn': 1.0,
          }),
        );
        await tester.pumpAndSettle();

        final submitButton = find.byKey(const Key('solver_submit_button'));
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(capturedSolverId, equals('euler'));
        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
        expect(find.byKey(const Key('curve_chart_repaint_boundary')), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 5: Numerical Integration (Trapezoidal) Home → Category → Workspace → Solve → Result',
      (tester) async {
        solverFormBloc = SolverFormBloc(
          executeSolverUseCase: mockExecuteSolverUseCase,
        );
        String? capturedSolverId;

        mockExecuteSolverUseCase.onCall = ({required solverId, required payload, accessToken}) async {
          capturedSolverId = solverId;
          return const Right(
            SolverResult(
              method: 'trapezoidal',
              status: 'converged',
              finalAnswer: {'integral': 0.335},
            ),
          );
        };

        await tester.pumpWidget(
          buildFlowApp(initialLocation: AppRoutes.workspace('integration', 'trapezoidal')),
        );
        await tester.pumpAndSettle();

        solverFormBloc.add(
          const SolverFormFieldsBulkChanged({
            'equation': 'x^2',
            'lowerBound': 0.0,
            'upperBound': 1.0,
            'subintervals': 10,
          }),
        );
        await tester.pumpAndSettle();

        final submitButton = find.byKey(const Key('solver_submit_button'));
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(capturedSolverId, equals('trapezoidal'));
        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 6: Differentiation (Function Finite Diff) Home → Category → Workspace → Solve → Result & Chart',
      (tester) async {
        solverFormBloc = SolverFormBloc(
          executeSolverUseCase: mockExecuteSolverUseCase,
        );
        String? capturedSolverId;

        mockExecuteSolverUseCase.onCall = ({required solverId, required payload, accessToken}) async {
          capturedSolverId = solverId;
          return const Right(
            SolverResult(
              method: 'function-finite-difference',
              status: 'converged',
              finalAnswer: {'derivative': 4.001},
              graphData: <String, dynamic>{
                'originalPoints': <Map<String, dynamic>>[
                  {'x': 1.0, 'y': 1.0},
                  {'x': 2.0, 'y': 4.0},
                ],
                'stencilPoints': <Map<String, dynamic>>[
                  {'x': 1.0, 'y': 1.0},
                  {'x': 2.0, 'y': 4.0},
                ],
                'derivativePoint': {'x': 2.0, 'y': 4.0},
                'targetX': 2.0,
              },
            ),
          );
        };

        await tester.pumpWidget(
          buildFlowApp(initialLocation: AppRoutes.workspace('differentiation', 'function-finite-difference')),
        );
        await tester.pumpAndSettle();

        solverFormBloc.add(
          const SolverFormFieldsBulkChanged({
            'equation': 'x^2',
            'targetX': 2.0,
            'h': 0.001,
            'variant': 'forward',
          }),
        );
        await tester.pumpAndSettle();

        final submitButton = find.byKey(const Key('solver_submit_button'));
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(capturedSolverId, equals('function-finite-difference'));
        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
        expect(find.byKey(const Key('differentiation_chart_repaint_boundary')), findsOneWidget);
      },
    );

    testWidgets('legacy direct solver route /solver/:solverId redirects to category workspace', (
      tester,
    ) async {
      solverFormBloc = SolverFormBloc(
        executeSolverUseCase: mockExecuteSolverUseCase,
      );
      await tester.pumpWidget(buildFlowApp(initialLocation: AppRoutes.solver('bisection')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('solver_workspace_screen')), findsOneWidget);
      expect(find.text('Active Method: Bisection Method'), findsOneWidget);
    });
  });

  group('4. Parameterized Verification for All 27 Registry Methods', () {
    Map<String, dynamic> generateFixture(SolverMethodConfig config) {
      final defaults = config.defaultPayload();
      final fixture = <String, dynamic>{...defaults};

      for (final field in config.fields) {
        if (!fixture.containsKey(field.name) || fixture[field.name] == null) {
          switch (field.type) {
            case SolverInputFieldType.equation:
              if (config.category == SolverCategory.ode) {
                fixture[field.name] = 'x + y';
              } else {
                fixture[field.name] = 'x^2 - 4';
              }
            case SolverInputFieldType.number:
              if (field.name == 'lowerBound' ||
                  field.name == 'x0' ||
                  field.name == 'firstGuess') {
                fixture[field.name] = 1.0;
              } else if (field.name == 'upperBound' ||
                  field.name == 'x1' ||
                  field.name == 'targetX' ||
                  field.name == 'xn' ||
                  field.name == 'secondGuess') {
                fixture[field.name] = 3.0;
              } else if (field.name == 'y0') {
                fixture[field.name] = 1.0;
              } else if (field.name == 'h' || field.name == 'stepSize') {
                fixture[field.name] = 0.1;
              } else {
                fixture[field.name] = 1.0;
              }
            case SolverInputFieldType.integer:
              if (field.name == 'subintervals') {
                fixture[field.name] = 12; // Divisible by 2 and 3
              } else {
                fixture[field.name] = 10;
              }
            case SolverInputFieldType.matrix:
              fixture[field.name] = [
                [4.0, 1.0],
                [1.0, 3.0],
              ];
            case SolverInputFieldType.vector:
              if (field.name == 'constants') {
                fixture[field.name] = [1.0, 2.0];
              } else {
                fixture[field.name] = [0.0, 0.0];
              }
            case SolverInputFieldType.pointList:
              fixture[field.name] = [
                {'x': 1.0, 'y': 1.0},
                {'x': 2.0, 'y': 4.0},
                {'x': 3.0, 'y': 9.0},
                {'x': 4.0, 'y': 16.0},
              ];
            case SolverInputFieldType.select:
              if (field.options != null && field.options!.isNotEmpty) {
                fixture[field.name] = field.options!.first.value;
              }
            case SolverInputFieldType.boolean:
              fixture[field.name] = true;
          }
        }
      }

      // Solver-specific adjustments for exact schema constraints
      if (config.category == SolverCategory.ode) {
        fixture['x0'] = 0.0;
        fixture['h'] = 0.1;
        fixture['xn'] = 1.0;
        fixture.remove('steps');
      } else if (config.id == 'forward-difference-tabular') {
        fixture['targetX'] = 1.0;
      } else if (config.id == 'backward-difference-tabular') {
        fixture['targetX'] = 4.0;
      } else if (config.id == 'central-difference-tabular') {
        fixture['targetX'] = 2.0;
      }

      return fixture;
    }

    test('all 27 methods can be initialized with schema fixtures and submitted cleanly', () async {
      for (final config in SolverMethodRegistry.all) {
        final mockUseCase = MockExecuteSolverUseCase();
        String? capturedSolverId;
        Map<String, dynamic>? capturedPayload;

        mockUseCase.onCall = ({required solverId, required payload, accessToken}) async {
          capturedSolverId = solverId;
          capturedPayload = payload;
          return Right(
            SolverResult(
              method: solverId,
              finalAnswer: const {'status': 'ok'},
            ),
          );
        };

        final bloc = SolverFormBloc(executeSolverUseCase: mockUseCase)
          ..add(SolverFormLoadStarted(solverId: config.id));
        await bloc.stream.firstWhere((s) => s.isReady && s.config?.id == config.id);

        final fixture = generateFixture(config);
        final errors = config.validate(fixture);
        expect(
          errors,
          isEmpty,
          reason: 'Fixture for ${config.id} must be valid but had errors: $errors',
        );

        bloc.add(SolverFormFieldsBulkChanged(fixture));
        await bloc.stream.firstWhere((s) => s.isReady && s.fieldErrors.isEmpty);

        // Submit form
        bloc.add(const SolverFormSubmitted());
        final submittedState = await bloc.stream.firstWhere((s) => s.isSuccess);

        expect(submittedState.isSuccess, isTrue);
        expect(capturedSolverId, equals(config.id));
        expect(capturedPayload, isNotNull);

        // Verify payload only contains fields declared in the schema
        final allowedNames = config.fields.map((f) => f.name).toSet();
        for (final key in capturedPayload!.keys) {
          expect(
            allowedNames.contains(key),
            isTrue,
            reason: 'Payload key "$key" must belong to ${config.id} schema',
          );
        }

        await bloc.close();
      }
    });
  });
}

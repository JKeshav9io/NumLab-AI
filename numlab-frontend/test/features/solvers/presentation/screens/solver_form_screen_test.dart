import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/entities.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/presentation/screens/screens.dart';

class MockSolverFormBloc extends Fake implements SolverFormBloc {
  MockSolverFormBloc(this._initialState) {
    _state = _initialState;
  }

  final SolverFormState _initialState;
  late SolverFormState _state;
  final StreamController<SolverFormState> _controller =
      StreamController<SolverFormState>.broadcast();
  final List<SolverFormEvent> recordedEvents = [];

  @override
  SolverFormState get state => _state;

  @override
  Stream<SolverFormState> get stream => _controller.stream;

  @override
  void add(SolverFormEvent event) {
    recordedEvents.add(event);
  }

  void emitState(SolverFormState newState) {
    _state = newState;
    _controller.add(newState);
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  late MockSolverFormBloc mockSolverFormBloc;

  final tBisectionConfig = SolverMethodRegistry.getById('bisection')!;

  tearDown(() async {
    await mockSolverFormBloc.close();
  });

  Widget buildSolverFormScreen({
    required String solverId,
    MockSolverFormBloc? bloc,
  }) {
    return MaterialApp(
      home: BlocProvider<SolverFormBloc>.value(
        value: bloc ?? mockSolverFormBloc,
        child: SolverFormScreen(solverId: solverId),
      ),
    );
  }

  group('SolverFormScreen Loading & Error State Tests', () {
    testWidgets(
      'renders loading indicator when state.isLoadingConfig is true',
      (
        tester,
      ) async {
        mockSolverFormBloc = MockSolverFormBloc(
          const SolverFormState(
            status: SolverFormStatus.loadingConfig,
          ),
        );

        await tester.pumpWidget(
          buildSolverFormScreen(solverId: 'bisection'),
        );

        expect(
          find.byKey(const Key('solver_loading_indicator')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('solver_name')), findsNothing);
      },
    );

    testWidgets(
      'renders error message and Go Back button when solver is unknown',
      (
        tester,
      ) async {
        mockSolverFormBloc = MockSolverFormBloc(
          const SolverFormState(
            status: SolverFormStatus.failure,
            failure: ValidationFailure(
              message: 'Unknown solver method ID: "non_existent_solver"',
            ),
          ),
        );

        await tester.pumpWidget(
          buildSolverFormScreen(solverId: 'non_existent_solver'),
        );

        expect(find.byKey(const Key('solver_error_message')), findsOneWidget);
        expect(
          find.text('Unknown solver method ID: "non_existent_solver"'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('solver_back_button')), findsOneWidget);
      },
    );

    testWidgets('tapping Go Back button in error state pops router', (
      tester,
    ) async {
      mockSolverFormBloc = MockSolverFormBloc(
        const SolverFormState(
          status: SolverFormStatus.failure,
          failure: ValidationFailure(
            message: 'Solver configuration not found',
          ),
        ),
      );

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                key: const Key('navigate_to_solver'),
                onPressed: () => context.push('/solver/invalid'),
                child: const Text('Go'),
              ),
            ),
          ),
          GoRoute(
            path: '/solver/:solverId',
            builder: (context, state) => BlocProvider<SolverFormBloc>.value(
              value: mockSolverFormBloc,
              child: const SolverFormScreen(solverId: 'invalid'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('navigate_to_solver')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('solver_back_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('solver_back_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('navigate_to_solver')), findsOneWidget);
    });

    testWidgets(
      'renders unloaded text fallback when config is null without failure',
      (
        tester,
      ) async {
        mockSolverFormBloc = MockSolverFormBloc(
          const SolverFormState(),
        );

        await tester.pumpWidget(
          buildSolverFormScreen(solverId: 'bisection'),
        );

        expect(find.byKey(const Key('solver_unloaded_text')), findsOneWidget);
        expect(find.text('No solver loaded'), findsOneWidget);
      },
    );
  });

  group('SolverFormScreen Configuration & Form Rendering Tests', () {
    setUp(() {
      mockSolverFormBloc = MockSolverFormBloc(
        SolverFormState(
          status: SolverFormStatus.ready,
          config: tBisectionConfig,
          values: const {
            'f': 'x^2 - 4',
            'a': 0.0,
            'b': 3.0,
            'tolerance': 0.0001,
            'max_iterations': 100,
          },
        ),
      );
    });

    testWidgets(
      'renders solver title, category, description, endpoint, and fields',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSolverFormScreen(solverId: 'bisection'),
        );

        expect(find.byKey(const Key('solver_appbar_title')), findsOneWidget);
        expect(find.byKey(const Key('solver_name')), findsOneWidget);
        expect(find.text('Bisection Method'), findsWidgets);
        expect(find.byKey(const Key('solver_category')), findsOneWidget);
        expect(find.text('Root Finding'), findsOneWidget);
        expect(find.byKey(const Key('solver_description')), findsOneWidget);
        expect(find.byKey(const Key('solver_endpoint')), findsOneWidget);
        expect(
          find.text('API Endpoint: ${tBisectionConfig.endpoint}'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('dynamic_solver_form')), findsOneWidget);
        expect(find.byKey(const Key('solver_reset_button')), findsOneWidget);
        expect(find.byKey(const Key('solver_submit_button')), findsOneWidget);
        expect(find.text('Run Solver'), findsOneWidget);
      },
    );

    testWidgets('tapping submit button dispatches SolverFormSubmitted', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSolverFormScreen(solverId: 'bisection'),
      );

      await tester.ensureVisible(find.byKey(const Key('solver_submit_button')));
      await tester.tap(find.byKey(const Key('solver_submit_button')));
      await tester.pump();

      expect(
        mockSolverFormBloc.recordedEvents,
        contains(const SolverFormSubmitted()),
      );
    });

    testWidgets(
      'renders loading state and disables submit button when isSubmitting',
      (
        tester,
      ) async {
        mockSolverFormBloc = MockSolverFormBloc(
          SolverFormState(
            status: SolverFormStatus.submitting,
            config: tBisectionConfig,
          ),
        );

        await tester.pumpWidget(
          buildSolverFormScreen(solverId: 'bisection'),
        );

        expect(find.text('Calculating...'), findsOneWidget);
        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('solver_submit_button')),
        );
        expect(button.onPressed, isNull);
      },
    );
  });

  group('SolverFormScreen Execution Results & Errors Tests', () {
    testWidgets('renders execution error banner when calculation fails', (
      tester,
    ) async {
      mockSolverFormBloc = MockSolverFormBloc(
        SolverFormState(
          status: SolverFormStatus.failure,
          config: tBisectionConfig,
          failure: const ServerFailure(
            message: 'f(a) and f(b) must have opposite signs',
          ),
        ),
      );

      await tester.pumpWidget(
        buildSolverFormScreen(solverId: 'bisection'),
      );

      expect(
        find.byKey(const Key('solver_execution_error_banner')),
        findsOneWidget,
      );
      expect(
        find.text('f(a) and f(b) must have opposite signs'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders calculation result card when solver execution succeeds',
      (
        tester,
      ) async {
        const tResult = SolverResult(
          method: 'bisection',
          finalAnswer: {'root': 2.0, 'iterations': 15},
          executionTimeMs: 1,
        );

        mockSolverFormBloc = MockSolverFormBloc(
          SolverFormState(
            status: SolverFormStatus.success,
            config: tBisectionConfig,
            result: tResult,
          ),
        );

        await tester.pumpWidget(
          buildSolverFormScreen(solverId: 'bisection'),
        );

        expect(find.byKey(const Key('solver_result_card')), findsOneWidget);
        expect(find.text('Calculation Result'), findsOneWidget);
        expect(find.byKey(const Key('solver_result_display')), findsOneWidget);
        expect(find.text('Method: bisection'), findsOneWidget);
        expect(find.text('Root: 2.0'), findsOneWidget);
      },
    );

    testWidgets(
      'dynamic state emission transitions from ready to submitting to result',
      (
        tester,
      ) async {
        mockSolverFormBloc = MockSolverFormBloc(
          SolverFormState(
            status: SolverFormStatus.ready,
            config: tBisectionConfig,
          ),
        );

        await tester.pumpWidget(
          buildSolverFormScreen(solverId: 'bisection'),
        );

        expect(find.text('Run Solver'), findsOneWidget);
        expect(find.byKey(const Key('solver_result_card')), findsNothing);

        // Transition to Submitting
        mockSolverFormBloc.emitState(
          SolverFormState(
            status: SolverFormStatus.submitting,
            config: tBisectionConfig,
          ),
        );
        await tester.pump();
        expect(find.text('Calculating...'), findsOneWidget);

        // Transition to Success
        const tResult = SolverResult(
          method: 'bisection',
          finalAnswer: {'root': 2.0},
        );
        mockSolverFormBloc.emitState(
          SolverFormState(
            status: SolverFormStatus.success,
            config: tBisectionConfig,
            result: tResult,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('solver_result_card')), findsOneWidget);
        expect(find.text('Root: 2.0'), findsOneWidget);
      },
    );
  });
}

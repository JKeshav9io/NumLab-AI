import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/entities.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/widgets.dart';

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

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  late MockSolverFormBloc mockBloc;

  tearDown(() async {
    await mockBloc.close();
  });

  Widget buildDynamicForm({
    required SolverMethodConfig config,
    required SolverFormState state,
    MockSolverFormBloc? bloc,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlocProvider<SolverFormBloc>.value(
            value: bloc ?? mockBloc,
            child: DynamicSolverForm(
              config: config,
              state: state,
            ),
          ),
        ),
      ),
    );
  }

  group('DynamicSolverForm - Field Generation & Defaults', () {
    testWidgets('renders all input fields for Bisection solver with defaults', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('bisection')!;
      final state = SolverFormState(
        status: SolverFormStatus.ready,
        config: config,
        values: config.defaultPayload(),
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      // Verify text/numeric fields
      expect(find.byKey(const Key('field_equation')), findsOneWidget);
      expect(find.byKey(const Key('field_lowerBound')), findsOneWidget);
      expect(find.byKey(const Key('field_upperBound')), findsOneWidget);
      expect(find.byKey(const Key('field_tolerance')), findsOneWidget);
      expect(find.byKey(const Key('field_maxIterations')), findsOneWidget);
      expect(find.byKey(const Key('field_includeExplanation')), findsOneWidget);
      expect(find.byKey(const Key('field_includeGraphData')), findsOneWidget);

      // Verify default values populated
      expect(find.text('0.0001'), findsWidgets);
      expect(find.text('100'), findsWidgets);

      // Required indicators
      expect(find.text('Equation f(x) *'), findsOneWidget);
      expect(find.text('Lower Bound (a) *'), findsOneWidget);
      expect(find.text('Upper Bound (b) *'), findsOneWidget);
    });

    testWidgets(
      'renders matrix and vector fields for Gauss Elimination solver',
      (
        tester,
      ) async {
        final config = SolverMethodRegistry.getById('gauss-elimination')!;
        final state = SolverFormState(
          status: SolverFormStatus.ready,
          config: config,
          values: const {
            'matrix': [
              [2.0, 1.0],
              [1.0, 3.0],
            ],
            'constants': [8.0, 9.0],
          },
        );
        mockBloc = MockSolverFormBloc(state);

        await tester.pumpWidget(
          buildDynamicForm(config: config, state: state),
        );

        expect(find.byKey(const Key('field_matrix')), findsOneWidget);
        expect(find.byKey(const Key('field_constants')), findsOneWidget);
        expect(
          find.byKey(const Key('field_includeExplanation')),
          findsOneWidget,
        );

        // Values formatted in fields
        expect(find.text('2.0, 1.0\n1.0, 3.0'), findsOneWidget);
        expect(find.text('8.0, 9.0'), findsOneWidget);
      },
    );

    testWidgets(
      'renders point list and numeric target for Lagrange Interpolation',
      (
        tester,
      ) async {
        final config = SolverMethodRegistry.getById('lagrange')!;
        final state = SolverFormState(
          status: SolverFormStatus.ready,
          config: config,
          values: const {
            'points': [
              {'x': 1.0, 'y': 2.0},
              {'x': 2.0, 'y': 3.0},
              {'x': 4.0, 'y': 7.0},
            ],
            'targetX': 3.0,
          },
        );
        mockBloc = MockSolverFormBloc(state);

        await tester.pumpWidget(
          buildDynamicForm(config: config, state: state),
        );

        expect(find.byKey(const Key('field_points')), findsOneWidget);
        expect(find.byKey(const Key('field_targetX')), findsOneWidget);
        expect(find.text('1.0, 2.0\n2.0, 3.0\n4.0, 7.0'), findsOneWidget);
        expect(find.text('3.0'), findsOneWidget);
      },
    );

    testWidgets('renders select dropdown field for Central Difference solver', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('central-difference')!;
      final state = SolverFormState(
        status: SolverFormStatus.ready,
        config: config,
        values: config.defaultPayload(),
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      expect(find.byKey(const Key('field_points')), findsOneWidget);
      expect(find.byKey(const Key('field_targetX')), findsOneWidget);
      expect(find.byKey(const Key('field_variant')), findsOneWidget);
      expect(find.text('Stirling Formula'), findsOneWidget);
    });
  });

  group('DynamicSolverForm - User Input Updates BLoC', () {
    testWidgets(
      'editing equation and numeric fields dispatches SolverFormFieldChanged',
      (
        tester,
      ) async {
        final config = SolverMethodRegistry.getById('bisection')!;
        final state = SolverFormState(
          status: SolverFormStatus.ready,
          config: config,
          values: config.defaultPayload(),
        );
        mockBloc = MockSolverFormBloc(state);

        await tester.pumpWidget(
          buildDynamicForm(config: config, state: state),
        );

        // Edit equation
        await tester.enterText(
          find.byKey(const Key('field_equation')),
          'cos(x) - x',
        );
        await tester.pump();

        expect(
          mockBloc.recordedEvents,
          contains(
            const SolverFormFieldChanged(
              fieldName: 'equation',
              value: 'cos(x) - x',
            ),
          ),
        );

        // Edit number lowerBound
        await tester.enterText(
          find.byKey(const Key('field_lowerBound')),
          '0.5',
        );
        await tester.pump();

        expect(
          mockBloc.recordedEvents,
          contains(
            const SolverFormFieldChanged(
              fieldName: 'lowerBound',
              value: 0.5,
            ),
          ),
        );

        // Edit integer maxIterations
        await tester.ensureVisible(
          find.byKey(const Key('field_maxIterations')),
        );
        await tester.enterText(
          find.byKey(const Key('field_maxIterations')),
          '50',
        );
        await tester.pump();

        expect(
          mockBloc.recordedEvents,
          contains(
            const SolverFormFieldChanged(
              fieldName: 'maxIterations',
              value: 50,
            ),
          ),
        );
      },
    );

    testWidgets('toggling boolean switch dispatches SolverFormFieldChanged', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('bisection')!;
      final state = SolverFormState(
        status: SolverFormStatus.ready,
        config: config,
        values: config.defaultPayload(),
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      await tester.ensureVisible(
        find.byKey(const Key('field_includeExplanation')),
      );
      await tester.tap(find.byKey(const Key('field_includeExplanation')));
      await tester.pump();

      expect(
        mockBloc.recordedEvents,
        contains(
          const SolverFormFieldChanged(
            fieldName: 'includeExplanation',
            value: false,
          ),
        ),
      );
    });

    testWidgets('changing select dropdown dispatches SolverFormFieldChanged', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('central-difference')!;
      final state = SolverFormState(
        status: SolverFormStatus.ready,
        config: config,
        values: config.defaultPayload(),
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      await tester.ensureVisible(find.byKey(const Key('field_variant')));
      await tester.tap(find.byKey(const Key('field_variant')));
      await tester.pumpAndSettle();

      // Tap 'Bessel Formula' option
      await tester.tap(find.text('Bessel Formula').last);
      await tester.pumpAndSettle();

      expect(
        mockBloc.recordedEvents,
        contains(
          const SolverFormFieldChanged(
            fieldName: 'variant',
            value: 'bessel',
          ),
        ),
      );
    });

    testWidgets('editing vector field parses List<num> and dispatches change', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('gauss-elimination')!;
      final state = SolverFormState(
        status: SolverFormStatus.ready,
        config: config,
        values: config.defaultPayload(),
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      await tester.ensureVisible(find.byKey(const Key('field_constants')));
      await tester.enterText(
        find.byKey(const Key('field_constants')),
        '10.5, 20.2',
      );
      await tester.pump();

      expect(
        mockBloc.recordedEvents,
        contains(
          const SolverFormFieldChanged(
            fieldName: 'constants',
            value: [10.5, 20.2],
          ),
        ),
      );
    });

    testWidgets(
      'editing matrix field parses List<List<num>> and dispatches change',
      (
        tester,
      ) async {
        final config = SolverMethodRegistry.getById('gauss-elimination')!;
        final state = SolverFormState(
          status: SolverFormStatus.ready,
          config: config,
          values: config.defaultPayload(),
        );
        mockBloc = MockSolverFormBloc(state);

        await tester.pumpWidget(
          buildDynamicForm(config: config, state: state),
        );

        await tester.enterText(
          find.byKey(const Key('field_matrix')),
          '4.0, 2.0\n1.0, 5.0',
        );
        await tester.pump();

        expect(
          mockBloc.recordedEvents,
          contains(
            const SolverFormFieldChanged(
              fieldName: 'matrix',
              value: [
                [4.0, 2.0],
                [1.0, 5.0],
              ],
            ),
          ),
        );
      },
    );

    testWidgets(
      'editing point list field parses coordinate list and dispatches change',
      (
        tester,
      ) async {
        final config = SolverMethodRegistry.getById('lagrange')!;
        final state = SolverFormState(
          status: SolverFormStatus.ready,
          config: config,
          values: config.defaultPayload(),
        );
        mockBloc = MockSolverFormBloc(state);

        await tester.pumpWidget(
          buildDynamicForm(config: config, state: state),
        );

        await tester.enterText(
          find.byKey(const Key('field_points')),
          '0.0, 1.0\n1.0, 3.0\n2.0, 9.0',
        );
        await tester.pump();

        expect(
          mockBloc.recordedEvents,
          contains(
            const SolverFormFieldChanged(
              fieldName: 'points',
              value: [
                {'x': 0.0, 'y': 1.0},
                {'x': 1.0, 'y': 3.0},
                {'x': 2.0, 'y': 9.0},
              ],
            ),
          ),
        );
      },
    );
  });

  group('DynamicSolverForm - Validation Errors & Reset & Submit', () {
    testWidgets('displays field-level validation errors correctly', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('bisection')!;
      final state = SolverFormState(
        status: SolverFormStatus.failure,
        config: config,
        values: config.defaultPayload(),
        fieldErrors: const {
          'equation': 'Equation is required',
          'tolerance': 'Tolerance must be strictly positive',
        },
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      expect(find.text('Equation is required'), findsOneWidget);
      expect(find.text('Tolerance must be strictly positive'), findsOneWidget);
    });

    testWidgets('displays cross-field validation errors banner', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('bisection')!;
      final state = SolverFormState(
        status: SolverFormStatus.failure,
        config: config,
        values: config.defaultPayload(),
        fieldErrors: const {
          'bounds.ordered':
              'Interval start (a) must be strictly less than interval end (b)',
        },
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      expect(find.byKey(const Key('cross_field_error_banner')), findsOneWidget);
      expect(
        find.byKey(const Key('cross_field_error_bounds.ordered')),
        findsOneWidget,
      );
      expect(
        find.text(
          '• Interval start (a) must be strictly less than interval end (b)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping Reset button dispatches SolverFormResetRequested', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('bisection')!;
      final state = SolverFormState(
        status: SolverFormStatus.ready,
        config: config,
        values: config.defaultPayload(),
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      await tester.ensureVisible(find.byKey(const Key('solver_reset_button')));
      await tester.tap(find.byKey(const Key('solver_reset_button')));
      await tester.pump();

      expect(
        mockBloc.recordedEvents,
        contains(const SolverFormResetRequested()),
      );
    });

    testWidgets('tapping Submit button dispatches SolverFormSubmitted', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('bisection')!;
      final state = SolverFormState(
        status: SolverFormStatus.ready,
        config: config,
        values: config.defaultPayload(),
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      await tester.ensureVisible(find.byKey(const Key('solver_submit_button')));
      await tester.tap(find.byKey(const Key('solver_submit_button')));
      await tester.pump();

      expect(
        mockBloc.recordedEvents,
        contains(const SolverFormSubmitted()),
      );
    });

    testWidgets('disables action buttons during submitting state', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('bisection')!;
      final state = SolverFormState(
        status: SolverFormStatus.submitting,
        config: config,
        values: config.defaultPayload(),
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      final submitButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('solver_submit_button')),
      );
      expect(submitButton.onPressed, isNull);

      final resetButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('solver_reset_button')),
      );
      expect(resetButton.onPressed, isNull);

      expect(find.text('Calculating...'), findsOneWidget);
    });

    testWidgets('renders execution error banner when general failure occurs', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('bisection')!;
      final state = SolverFormState(
        status: SolverFormStatus.failure,
        config: config,
        values: config.defaultPayload(),
        failure: const ServerFailure(message: 'Server failed to calculate'),
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      expect(
        find.byKey(const Key('solver_execution_error_banner')),
        findsOneWidget,
      );
      expect(find.text('Server failed to calculate'), findsOneWidget);
    });

    testWidgets('renders calculation result card when result is present', (
      tester,
    ) async {
      final config = SolverMethodRegistry.getById('bisection')!;
      const tResult = SolverResult(
        method: 'bisection',
        finalAnswer: {
          'root': 1.5213,
          'iterations': 14,
        },
        executionTimeMs: 2,
      );
      final state = SolverFormState(
        status: SolverFormStatus.success,
        config: config,
        values: config.defaultPayload(),
        result: tResult,
      );
      mockBloc = MockSolverFormBloc(state);

      await tester.pumpWidget(
        buildDynamicForm(config: config, state: state),
      );

      expect(find.byKey(const Key('solver_result_card')), findsOneWidget);
      expect(find.text('Calculation Result'), findsOneWidget);
      expect(find.text('Method: bisection'), findsOneWidget);
      expect(find.text('Root: 1.5213'), findsOneWidget);
      expect(find.text('Iterations: 14'), findsOneWidget);
      expect(find.text('Time: 2 ms'), findsOneWidget);
    });
  });

  group(
    'DynamicSolverForm - Complex Solvers & Stability for All 27 Solvers',
    () {
      testWidgets(
        'renders complex Jacobi Method with matrix, vector, initialGuess vector',
        (
          tester,
        ) async {
          final config = SolverMethodRegistry.getById('jacobi')!;
          final state = SolverFormState(
            status: SolverFormStatus.ready,
            config: config,
            values: config.defaultPayload(),
          );
          mockBloc = MockSolverFormBloc(state);

          await tester.pumpWidget(
            buildDynamicForm(config: config, state: state),
          );

          expect(find.byKey(const Key('field_matrix')), findsOneWidget);
          expect(find.byKey(const Key('field_constants')), findsOneWidget);
          expect(find.byKey(const Key('field_initialGuess')), findsOneWidget);
          expect(find.byKey(const Key('field_tolerance')), findsOneWidget);
          expect(
            find.byKey(const Key('field_maxIterations')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders ODE Euler method with f(x, y) equation and initial conditions',
        (
          tester,
        ) async {
          final config = SolverMethodRegistry.getById('euler')!;
          final state = SolverFormState(
            status: SolverFormStatus.ready,
            config: config,
            values: config.defaultPayload(),
          );
          mockBloc = MockSolverFormBloc(state);

          await tester.pumpWidget(
            buildDynamicForm(config: config, state: state),
          );

          expect(find.byKey(const Key('field_equation')), findsOneWidget);
          expect(find.byKey(const Key('field_x0')), findsOneWidget);
          expect(find.byKey(const Key('field_y0')), findsOneWidget);
          expect(find.byKey(const Key('field_h')), findsOneWidget);
          expect(find.byKey(const Key('field_xn')), findsOneWidget);
          expect(find.byKey(const Key('field_steps')), findsOneWidget);
        },
      );

      testWidgets('builds forms for all 27 solver configs without crashing', (
        tester,
      ) async {
        final allConfigs = SolverMethodRegistry.all;
        expect(allConfigs.length, equals(27));

        for (final config in allConfigs) {
          final state = SolverFormState(
            status: SolverFormStatus.ready,
            config: config,
            values: config.defaultPayload(),
          );
          mockBloc = MockSolverFormBloc(state);

          await tester.pumpWidget(
            buildDynamicForm(config: config, state: state),
          );

          // Verify root widget and buttons render for every solver
          expect(
            find.byKey(const Key('dynamic_solver_form')),
            findsOneWidget,
            reason: 'Failed to build dynamic form for solver: ${config.id}',
          );
          expect(
            find.byKey(const Key('solver_submit_button')),
            findsOneWidget,
            reason: 'Submit button missing for solver: ${config.id}',
          );
          expect(
            find.byKey(const Key('solver_reset_button')),
            findsOneWidget,
            reason: 'Reset button missing for solver: ${config.id}',
          );

          // Verify each configured field has its corresponding widget rendered
          for (final field in config.fields) {
            expect(
              find.byKey(Key('field_${field.name}')),
              findsOneWidget,
              reason:
                  'Field "${field.name}" missing in form for solver "${config.id}"',
            );
          }
        }
      });
    },
  );
}

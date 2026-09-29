import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/entities.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/widgets.dart';

void main() {
  Widget buildResultView(SolverResult result) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SolverResultView(result: result),
          ),
        ),
      ),
    );
  }

  group('SolverResultView - Core Rendering & Metrics', () {
    testWidgets('renders method name, convergence status, and execution time', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'bisection',
        status: 'converged',
        executionTimeMs: 12,
        finalAnswer: {
          'root': 2.0945,
          'iterations': 15,
          'converged': true,
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
      expect(find.byKey(const Key('solver_result_card')), findsOneWidget);
      expect(find.text('Calculation Result'), findsOneWidget);
      expect(find.text('Method: bisection'), findsOneWidget);
      expect(find.byKey(const Key('solver_result_status')), findsOneWidget);
      expect(find.text('Status: converged'), findsOneWidget);
      expect(find.byKey(const Key('solver_result_time')), findsOneWidget);
      expect(find.text('Time: 12 ms'), findsOneWidget);
      expect(find.byKey(const Key('solver_result_iterations')), findsOneWidget);
      expect(find.text('Iterations: 15'), findsOneWidget);
    });

    testWidgets('renders root callout for root-finding result', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'newton-raphson',
        finalAnswer: {
          'root': 1.41421356,
          'f_root': 0.000001,
          'iterations': 4,
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_result_root')), findsOneWidget);
      expect(find.text('1.41421356'), findsWidgets);
    });

    testWidgets('renders solution vector for linear system result', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'gauss-elimination',
        finalAnswer: {
          'solution': [2.0, 3.0, -1.0],
          'determinant': 14.0,
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_result_solution')), findsOneWidget);
      expect(find.text('[ 2, 3, -1 ]'), findsWidgets);
    });

    testWidgets('renders scalar value and error metrics for calculus results', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'simpson-13',
        finalAnswer: {
          'integral': 3.14159,
          'error': 0.00002,
          'subintervals': 100,
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_result_value')), findsOneWidget);
      expect(find.text('3.14159'), findsWidgets);
      expect(find.byKey(const Key('solver_result_error')), findsOneWidget);
      expect(find.text('0.00002'), findsWidgets);
    });

    testWidgets(
      'renders graph data available badge when graphData is present',
      (
        tester,
      ) async {
        const resultWithGraph = SolverResult(
          method: 'bisection',
          finalAnswer: {'root': 2.0},
          graphData: {
            'curve': [
              {'x': 0, 'y': -2},
              {'x': 2, 'y': 0},
            ],
          },
        );

        await tester.pumpWidget(buildResultView(resultWithGraph));

        expect(
          find.byKey(const Key('solver_graph_available_badge')),
          findsOneWidget,
        );
        expect(find.text('Graph Data Available'), findsOneWidget);
      },
    );

    testWidgets('omits graph data badge when graphData is null or empty', (
      tester,
    ) async {
      const resultWithoutGraph = SolverResult(
        method: 'gauss-elimination',
        finalAnswer: {
          'solution': [1, 2],
        },
      );

      await tester.pumpWidget(buildResultView(resultWithoutGraph));

      expect(
        find.byKey(const Key('solver_graph_available_badge')),
        findsNothing,
      );
    });
  });

  group('SolverResultView - Warnings & Explanations & Iterations', () {
    testWidgets('renders warnings banner when warnings list is non-empty', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'jacobi',
        warnings: [
          'Matrix is not strictly diagonally dominant; convergence is not guaranteed',
          'Approaching maximum allowed iterations',
        ],
        finalAnswer: {
          'solution': [1.0, 2.0],
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_result_warnings')), findsOneWidget);
      expect(find.text('Solver Warnings'), findsOneWidget);
      expect(find.byKey(const Key('solver_warning_0')), findsOneWidget);
      expect(
        find.text(
          '• Matrix is not strictly diagonally dominant; convergence is not guaranteed',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('solver_warning_1')), findsOneWidget);
      expect(
        find.text('• Approaching maximum allowed iterations'),
        findsOneWidget,
      );
    });

    testWidgets('renders step-by-step explanation when present', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'bisection',
        finalAnswer: {'root': 2.0},
        explanation: SolverExplanation(
          summary: 'Root found in interval [1, 3] after 15 bisections.',
          steps: [
            'Evaluate f(1) = -2 and f(3) = 22 with opposite signs.',
            'Midpoint c = 2.0 has f(2.0) = 0.0.',
            'Convergence achieved within tolerance threshold.',
          ],
        ),
      );

      await tester.pumpWidget(buildResultView(result));

      expect(
        find.byKey(const Key('solver_result_explanation')),
        findsOneWidget,
      );
      expect(find.text('Step-by-Step Explanation'), findsOneWidget);
      expect(
        find.byKey(const Key('solver_explanation_summary')),
        findsOneWidget,
      );
      expect(
        find.text('Root found in interval [1, 3] after 15 bisections.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('solver_explanation_step_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('solver_explanation_step_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('solver_explanation_step_2')),
        findsOneWidget,
      );
    });

    testWidgets('renders iteration history table when iterations exist', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'bisection',
        finalAnswer: {'root': 1.5},
        iterations: [
          {'iteration': 1, 'a': 1.0, 'b': 2.0, 'c': 1.5, 'error': 0.5},
          {'iteration': 2, 'a': 1.0, 'b': 1.5, 'c': 1.25, 'error': 0.25},
        ],
      );

      await tester.pumpWidget(buildResultView(result));

      expect(
        find.byKey(const Key('solver_result_iterations_section')),
        findsOneWidget,
      );
      expect(find.text('Iteration Steps (2)'), findsOneWidget);

      // Expand the iterations section
      await tester.tap(
        find.byKey(const Key('solver_iterations_expansion_tile')),
      );
      await tester.pumpAndSettle();

      expect(find.text('0.5'), findsWidgets);
      expect(find.text('0.25'), findsWidgets);
    });

    testWidgets('renders request ID and timestamp metadata when available', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'bisection',
        finalAnswer: {'root': 2.0},
        requestId: 'req_numlab_9981',
        timestamp: '2026-09-29T00:00:00.000Z',
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_result_meta')), findsOneWidget);
      expect(find.text('Req: req_numlab_9981'), findsOneWidget);
      expect(find.text('2026-09-29T00:00:00.000Z'), findsOneWidget);
    });
  });

  group('SolverResultView - Complex Shapes Across Categories', () {
    testWidgets('handles 2D matrix results without crashing', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'matrix-inversion',
        finalAnswer: {
          'inverse': [
            [0.6, -0.2],
            [-0.2, 0.4],
          ],
          'determinant': 5.0,
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('final_answer_inverse')), findsOneWidget);
      expect(find.text('[ 0.6, -0.2 ]\n[ -0.2, 0.4 ]'), findsOneWidget);
      expect(find.byKey(const Key('final_answer_determinant')), findsOneWidget);
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('handles point list coordinate results (ODE trajectories)', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'euler',
        finalAnswer: {
          'finalY': 2.71828,
          'points': [
            {'x': 0.0, 'y': 1.0},
            {'x': 0.5, 'y': 1.6487},
            {'x': 1.0, 'y': 2.71828},
          ],
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('final_answer_finalY')), findsOneWidget);
      expect(find.byKey(const Key('final_answer_points')), findsOneWidget);
      expect(
        find.text('(0, 1), (0.5, 1.6487), (1, 2.71828)'),
        findsOneWidget,
      );
    });

    testWidgets('handles polynomial expression strings in Interpolation', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'lagrange',
        finalAnswer: {
          'interpolatedValue': 4.5,
          'polynomial': '1.5*x^2 - 0.5*x + 2.0',
          'degree': 2,
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(
        find.byKey(const Key('final_answer_interpolatedValue')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('final_answer_polynomial')), findsOneWidget);
      expect(find.text('1.5*x^2 - 0.5*x + 2.0'), findsOneWidget);
      expect(find.byKey(const Key('final_answer_degree')), findsOneWidget);
    });

    testWidgets(
      'gracefully handles empty finalAnswer and missing optional fields',
      (
        tester,
      ) async {
        const minimalResult = SolverResult(
          method: 'minimal-test',
          finalAnswer: {},
        );

        await tester.pumpWidget(buildResultView(minimalResult));

        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
        expect(find.text('Method: minimal-test'), findsOneWidget);
        expect(find.byKey(const Key('solver_result_warnings')), findsNothing);
        expect(
          find.byKey(const Key('solver_result_explanation')),
          findsNothing,
        );
        expect(find.byKey(const Key('solver_result_meta')), findsNothing);
      },
    );
  });

  group('SolverResultView - Phase 3b Graph Integration Tests', () {
    testWidgets(
      'renders CurveChartRenderer inside SolverResultView when curve graphData is present',
      (tester) async {
        const result = SolverResult(
          method: 'bisection',
          finalAnswer: {'root': 1.521},
          graphData: <Map<String, dynamic>>[
            {'x': 1, 'y': -2},
            {'x': 1.5, 'y': 0},
            {'x': 2, 'y': 4},
          ],
        );

        await tester.pumpWidget(buildResultView(result));

        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_view')), findsOneWidget);
        expect(
          find.byKey(const Key('solver_chart_view_repaint_boundary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('curve_chart_repaint_boundary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('solver_graph_available_badge')),
          findsOneWidget,
        );
        expect(find.text('bisection Graph'), findsOneWidget);
      },
    );

    testWidgets(
      'renders InterpolationChartRenderer inside SolverResultView when interpolation graphData is present',
      (tester) async {
        const result = SolverResult(
          method: 'lagrange',
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
        );

        await tester.pumpWidget(buildResultView(result));

        expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
        expect(
          find.byKey(const Key('interpolation_chart_repaint_boundary')),
          findsOneWidget,
        );
        expect(find.text('Polynomial Fit'), findsOneWidget);
        expect(find.text('Fitted Curve'), findsOneWidget);
        expect(find.text('Data Nodes (2)'), findsOneWidget);
      },
    );

    testWidgets(
      'renders DifferentiationChartRenderer inside SolverResultView when differentiation graphData is present',
      (tester) async {
        const result = SolverResult(
          method: 'forward-difference',
          finalAnswer: {'derivative': 5},
          graphData: <String, dynamic>{
            'originalPoints': <Map<String, dynamic>>[
              {'x': 1, 'y': 1},
              {'x': 2, 'y': 4},
            ],
            'stencilPoints': <Map<String, dynamic>>[
              {'x': 1, 'y': 1},
              {'x': 2, 'y': 4},
            ],
            'derivativePoint': {'x': 1.5, 'derivative': 5},
          },
        );

        await tester.pumpWidget(buildResultView(result));

        expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
        expect(
          find.byKey(const Key('differentiation_chart_repaint_boundary')),
          findsOneWidget,
        );
        expect(find.text('Stencil Plot'), findsOneWidget);
        expect(find.text('Tabular Points'), findsOneWidget);
        expect(find.text('Stencil Nodes (2)'), findsOneWidget);
      },
    );

    testWidgets(
      'does not render chart card when graphData is null or empty list',
      (tester) async {
        const result = SolverResult(
          method: 'gauss-elimination',
          finalAnswer: {
            'solution': [1, 2],
          },
          graphData: <dynamic>[],
        );

        await tester.pumpWidget(buildResultView(result));

        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_card')), findsNothing);
        expect(
          find.byKey(const Key('solver_graph_available_badge')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'does not crash and keeps rendering all other result sections when graphData is malformed',
      (tester) async {
        const result = SolverResult(
          method: 'bisection',
          finalAnswer: {'root': 2},
          graphData: 'completely_invalid_shape_not_a_map_or_list',
        );

        await tester.pumpWidget(buildResultView(result));

        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
        expect(find.byKey(const Key('solver_result_root')), findsOneWidget);
        expect(find.text('Root: 2'), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_card')), findsNothing);
      },
    );

    testWidgets(
      'renders chart seamlessly when typedGraphData is directly provided',
      (tester) async {
        const result = SolverResult(
          method: 'rk4',
          finalAnswer: {'y': 3},
          typedGraphData: CurveGraphData(
            points: [
              CoordinatePoint(x: 0, y: 1),
              CoordinatePoint(x: 1, y: 3),
            ],
            label: 'Trajectory',
          ),
        );

        await tester.pumpWidget(buildResultView(result));

        expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
        expect(
          find.byKey(const Key('curve_chart_repaint_boundary')),
          findsOneWidget,
        );
        expect(find.text('Trajectory'), findsOneWidget);
        expect(find.text('2 points'), findsOneWidget);
      },
    );
  });

  group('SolverResultView - Category-Specific Chart Rendering Matrix', () {
    testWidgets('1. Root Finding renders curve chart with function samples', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'newton-raphson',
        finalAnswer: {'root': 1.4142},
        graphData: [
          {'x': 1.0, 'y': -1.0},
          {'x': 1.5, 'y': 0.25},
          {'x': 2.0, 'y': 2.0},
        ],
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
      expect(
        find.byKey(const Key('curve_chart_repaint_boundary')),
        findsOneWidget,
      );
      expect(find.text('Curve Plot'), findsOneWidget);
      expect(find.text('3 points'), findsOneWidget);
    });

    testWidgets('2. ODE renders curve chart for trajectory steps', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'euler',
        finalAnswer: {'x': 1.0, 'y': 2.718},
        graphData: [
          {'x': 0.0, 'y': 1.0},
          {'x': 0.5, 'y': 1.5},
          {'x': 1.0, 'y': 2.25},
        ],
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
      expect(
        find.byKey(const Key('curve_chart_repaint_boundary')),
        findsOneWidget,
      );
      expect(find.text('Curve Plot'), findsOneWidget);
    });

    testWidgets('3. Numerical Integration renders curve chart for integrand', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'trapezoidal',
        finalAnswer: {'integral': 0.5},
        graphData: [
          {'x': 0.0, 'y': 0.0},
          {'x': 0.5, 'y': 0.5},
          {'x': 1.0, 'y': 1.0},
        ],
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
      expect(
        find.byKey(const Key('curve_chart_repaint_boundary')),
        findsOneWidget,
      );
      expect(find.text('Curve Plot'), findsOneWidget);
    });

    testWidgets('4. Function Differentiation renders curve chart', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'function-finite-difference',
        finalAnswer: {'derivative': 4.0},
        graphData: [
          {'x': 1.9, 'y': 3.61},
          {'x': 2.0, 'y': 4.0},
          {'x': 2.1, 'y': 4.41},
        ],
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
      expect(
        find.byKey(const Key('curve_chart_repaint_boundary')),
        findsOneWidget,
      );
      expect(find.text('Curve Plot'), findsOneWidget);
    });

    testWidgets('5. Interpolation renders polynomial fit multi-series chart', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'lagrange',
        finalAnswer: {'predictedY': 6.25},
        graphData: {
          'originalPoints': [
            {'x': 1, 'y': 1},
            {'x': 2, 'y': 4},
          ],
          'sampledCurve': [
            {'x': 1.0, 'y': 1.0},
            {'x': 1.5, 'y': 2.25},
            {'x': 2.0, 'y': 4.0},
          ],
          'predictedPoint': {'x': 1.5, 'y': 2.25},
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
      expect(
        find.byKey(const Key('interpolation_chart_repaint_boundary')),
        findsOneWidget,
      );
      expect(find.text('Polynomial Fit'), findsOneWidget);
      expect(find.text('Data Nodes (2)'), findsOneWidget);
      expect(find.text('Target (1.5, 2.25)'), findsOneWidget);
    });

    testWidgets('6. Tabular Differentiation renders stencil chart', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'central-difference',
        finalAnswer: {'derivative': 2.0},
        graphData: {
          'originalPoints': [
            {'x': 0, 'y': 0},
            {'x': 1, 'y': 1},
            {'x': 2, 'y': 4},
          ],
          'stencilPoints': [
            {'x': 0, 'y': 0},
            {'x': 2, 'y': 4},
          ],
          'derivativePoint': {'x': 1.0, 'derivative': 2.0},
        },
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
      expect(
        find.byKey(const Key('differentiation_chart_repaint_boundary')),
        findsOneWidget,
      );
      expect(find.text('Stencil Plot'), findsOneWidget);
      expect(find.text('Stencil Nodes (2)'), findsOneWidget);
    });

    testWidgets('7. Linear Algebra (no graph) renders no chart', (
      tester,
    ) async {
      const result = SolverResult(
        method: 'jacobi',
        finalAnswer: {
          'solution': [1.0, 2.0],
        },
        graphData: <dynamic>[],
      );

      await tester.pumpWidget(buildResultView(result));

      expect(find.byKey(const Key('solver_chart_card')), findsNothing);
      expect(
        find.byKey(const Key('solver_graph_available_badge')),
        findsNothing,
      );
    });

    testWidgets(
      '8. Malformed 2D matrix payload renders no chart and does not crash',
      (
        tester,
      ) async {
        const result = SolverResult(
          method: 'gauss-seidel',
          finalAnswer: {
            'solution': [1.0, 2.0, 3.0],
          },
          graphData: <dynamic>[
            [1.0, 2.0, 3.0],
            [4.0, 5.0, 6.0],
          ],
        );

        await tester.pumpWidget(buildResultView(result));

        expect(find.byKey(const Key('solver_result_view')), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_card')), findsNothing);
      },
    );
  });
}

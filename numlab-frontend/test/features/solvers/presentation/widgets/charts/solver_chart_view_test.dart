import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/theme/app_theme.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/charts.dart';

void main() {
  Widget buildTestChart(
    Widget child, {
    ThemeMode themeMode = ThemeMode.light,
    double width = 400,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ChartThemeAdapter - Numeric Formatting & Polish', () {
    test('formats axis numbers cleanly and handles edge cases', () {
      expect(ChartThemeAdapter.formatAxisNumber(2), '2');
      expect(ChartThemeAdapter.formatAxisNumber(0), '0');
      expect(ChartThemeAdapter.formatAxisNumber(0), '0');
      expect(ChartThemeAdapter.formatAxisNumber(1e-13), '0');
      expect(ChartThemeAdapter.formatAxisNumber(1.5), '1.5');
      expect(ChartThemeAdapter.formatAxisNumber(-3.25), '-3.25');
      expect(ChartThemeAdapter.formatAxisNumber(100000), '1.00e5');
      expect(ChartThemeAdapter.formatAxisNumber(0.00001), '1.00e-5');
    });

    test('formats tooltip numbers with high inspection precision', () {
      expect(ChartThemeAdapter.formatTooltipNumber(2), '2');
      expect(ChartThemeAdapter.formatTooltipNumber(0), '0');
      expect(ChartThemeAdapter.formatTooltipNumber(1.4142), '1.4142');
      expect(ChartThemeAdapter.formatTooltipNumber(-0.00025), '-0.0003');
      expect(ChartThemeAdapter.formatTooltipNumber(500000), '5.000e5');
    });

    testWidgets('builds touch data with series-aware tooltips and fit-inside', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              final touchData = ChartThemeAdapter.buildTouchData(
                context,
                seriesNameResolver: (index, spot) => 'Custom Series $index',
              );

              expect(touchData.enabled, isTrue);
              expect(touchData.touchTooltipData.fitInsideHorizontally, isTrue);
              expect(touchData.touchTooltipData.fitInsideVertically, isTrue);

              final getItems = touchData.touchTooltipData.getTooltipItems;
              final items = getItems([
                LineBarSpot(
                  LineChartBarData(spots: [const FlSpot(1.5, 3.25)]),
                  0,
                  const FlSpot(1.5, 3.25),
                ),
              ]);

              expect(items.length, 1);
              expect(items[0]?.text, 'Custom Series 0\n(1.5, 3.25)');

              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('SolverChartView - Curve Rendering & Theme Support', () {
    testWidgets(
      'renders curve chart, type badge, points count, and RepaintBoundary in Light theme',
      (tester) async {
        const curveData = CurveGraphData(
          points: [
            CoordinatePoint(x: 0, y: -2),
            CoordinatePoint(x: 1, y: 0),
            CoordinatePoint(x: 2, y: 4),
          ],
          label: 'Root Curve f(x)',
        );

        await tester.pumpWidget(
          buildTestChart(
            const SolverChartView(
              graphData: curveData,
              title: 'Bisection Method Function',
              subtitle: 'f(x) = x^3 - x - 2',
            ),
          ),
        );

        expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_view')), findsOneWidget);
        expect(find.byKey(const Key('solver_chart_title')), findsOneWidget);
        expect(find.text('Bisection Method Function'), findsOneWidget);
        expect(find.text('f(x) = x^3 - x - 2'), findsOneWidget);
        expect(
          find.byKey(const Key('solver_chart_type_badge')),
          findsOneWidget,
        );
        expect(find.text('Curve Plot'), findsOneWidget);

        // Verify RepaintBoundary isolation
        expect(
          find.byKey(const Key('solver_chart_view_repaint_boundary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('curve_chart_repaint_boundary')),
          findsOneWidget,
        );

        // Verify points count and legend
        expect(find.text('3 points'), findsOneWidget);
        expect(find.text('Root Curve f(x)'), findsOneWidget);
      },
    );

    testWidgets('renders dark mode cleanly without errors', (tester) async {
      const curveData = CurveGraphData(
        points: [
          CoordinatePoint(x: -1, y: 1),
          CoordinatePoint(x: 0, y: 0),
          CoordinatePoint(x: 1, y: 1),
        ],
      );

      await tester.pumpWidget(
        buildTestChart(
          const SolverChartView(
            graphData: curveData,
            showAreaFill: true,
          ),
          themeMode: ThemeMode.dark,
        ),
      );

      expect(find.byKey(const Key('solver_chart_view')), findsOneWidget);
      expect(find.byType(CurveChartRenderer), findsOneWidget);
    });
  });

  group('SolverChartView - Interpolation & Differentiation Multi-Series', () {
    testWidgets('renders interpolation multi-series chart and legend items', (
      tester,
    ) async {
      const interpData = InterpolationGraphData(
        originalPoints: [
          CoordinatePoint(x: 1, y: 2),
          CoordinatePoint(x: 3, y: 6),
        ],
        sampledCurve: [
          CoordinatePoint(x: 1, y: 2),
          CoordinatePoint(x: 2, y: 3.8),
          CoordinatePoint(x: 3, y: 6),
        ],
        predictedPoint: CoordinatePoint(x: 2, y: 3.8),
      );

      await tester.pumpWidget(
        buildTestChart(
          const SolverChartView(
            graphData: interpData,
            title: 'Lagrange Interpolation',
          ),
        ),
      );

      expect(find.byKey(const Key('solver_chart_view')), findsOneWidget);
      expect(find.text('Polynomial Fit'), findsOneWidget);
      expect(
        find.byKey(const Key('interpolation_chart_repaint_boundary')),
        findsOneWidget,
      );
      expect(find.text('Fitted Curve'), findsOneWidget);
      expect(find.text('Data Nodes (2)'), findsOneWidget);
      expect(find.text('Target (2.0, 3.8)'), findsOneWidget);
    });

    testWidgets('renders differentiation stencil chart and legend items', (
      tester,
    ) async {
      const diffData = DifferentiationGraphData(
        originalPoints: [
          CoordinatePoint(x: 1, y: 1),
          CoordinatePoint(x: 2, y: 4),
          CoordinatePoint(x: 3, y: 9),
        ],
        stencilPoints: [
          CoordinatePoint(x: 2, y: 4),
          CoordinatePoint(x: 3, y: 9),
        ],
        derivativePoint: CoordinatePoint(x: 2.5, y: 5),
      );

      await tester.pumpWidget(
        buildTestChart(
          const SolverChartView(
            graphData: diffData,
            title: 'Forward Difference',
          ),
        ),
      );

      expect(find.byKey(const Key('solver_chart_view')), findsOneWidget);
      expect(find.text('Stencil Plot'), findsOneWidget);
      expect(
        find.byKey(const Key('differentiation_chart_repaint_boundary')),
        findsOneWidget,
      );
      expect(find.text('Tabular Points'), findsOneWidget);
      expect(find.text('Stencil Nodes (2)'), findsOneWidget);
      expect(find.text('Derivative Point'), findsOneWidget);
    });
  });

  group('SolverChartView - Responsiveness & Edge Cases', () {
    testWidgets(
      'renders safely on narrow mobile viewport (320px) without overflow',
      (
        tester,
      ) async {
        const curveData = CurveGraphData(
          points: [
            CoordinatePoint(x: -5, y: 25),
            CoordinatePoint(x: 0, y: 0),
            CoordinatePoint(x: 5, y: 25),
          ],
          label: 'Parabola Curve',
        );

        await tester.pumpWidget(
          buildTestChart(
            const SolverChartView(
              graphData: curveData,
              title: 'Narrow Screen Test',
            ),
            width: 320,
          ),
        );

        expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
        expect(find.text('Narrow Screen Test'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('handles single-point dataset gracefully without crashing', (
      tester,
    ) async {
      const singlePointData = CurveGraphData(
        points: [
          CoordinatePoint(x: 4, y: 9),
        ],
        label: 'Single Node',
      );

      await tester.pumpWidget(
        buildTestChart(
          const SolverChartView(
            graphData: singlePointData,
            title: 'Single Point Graph',
          ),
        ),
      );

      expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
      expect(find.text('1 points'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'handles large numeric coordinates without crashing or overflow',
      (
        tester,
      ) async {
        const largeData = CurveGraphData(
          points: [
            CoordinatePoint(x: -1000000, y: -5000000),
            CoordinatePoint(x: 0, y: 0),
            CoordinatePoint(x: 1000000, y: 5000000),
          ],
        );

        await tester.pumpWidget(
          buildTestChart(
            const SolverChartView(
              graphData: largeData,
              title: 'Large Coordinates',
            ),
          ),
        );

        expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('handles flat horizontal and vertical lines safely', (
      tester,
    ) async {
      const flatLine = CurveGraphData(
        points: [
          CoordinatePoint(x: 1, y: 5),
          CoordinatePoint(x: 2, y: 5),
          CoordinatePoint(x: 3, y: 5),
        ],
      );

      await tester.pumpWidget(
        buildTestChart(
          const SolverChartView(
            graphData: flatLine,
            title: 'Flat Line',
          ),
        ),
      );

      expect(find.byKey(const Key('solver_chart_card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('safely parses raw JSON list payload on the fly', (
      tester,
    ) async {
      final rawPoints = <Map<String, dynamic>>[
        {'x': 0, 'y': 1},
        {'x': 1, 'y': 2.718},
      ];

      await tester.pumpWidget(
        buildTestChart(
          SolverChartView(
            rawGraphData: rawPoints,
            title: 'Euler Method Trajectory',
          ),
        ),
      );

      expect(find.byKey(const Key('solver_chart_view')), findsOneWidget);
      expect(find.text('Euler Method Trajectory'), findsOneWidget);
      expect(find.text('2 points'), findsOneWidget);
    });

    testWidgets('renders empty placeholder when graphData is null or empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestChart(
          const SolverChartView(),
        ),
      );

      expect(
        find.byKey(const Key('solver_chart_empty_placeholder')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('solver_chart_card')), findsNothing);
    });
  });
}

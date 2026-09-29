import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/chart_downsampler.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/curve_chart_renderer.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/differentiation_chart_renderer.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/interpolation_chart_renderer.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/charts/solver_chart_view.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_result_view.dart';

void main() {
  group('Phase 3e — Chart Performance & Scalability (LTTB Downsampling)', () {
    test(
      'small datasets (<= 500 points) are preserved without downsampling',
      () {
        final points = List.generate(
          100,
          (i) => CoordinatePoint(x: i.toDouble(), y: math.sin(i * 0.1)),
        );

        final downsampled = ChartDownsampler.downsample(points);

        expect(downsampled.length, 100);
        expect(downsampled.first.x, 0.0);
        expect(downsampled.last.x, 99.0);
        expect(identical(downsampled, points), isTrue);
      },
    );

    test('exact 500 points dataset is preserved without downsampling', () {
      final points = List.generate(
        500,
        (i) => CoordinatePoint(x: i.toDouble(), y: i.toDouble()),
      );

      final downsampled = ChartDownsampler.downsample(points);

      expect(downsampled.length, 500);
      expect(downsampled.first.x, 0.0);
      expect(downsampled.last.x, 499.0);
    });

    test(
      '1,000 points dataset is downsampled to exactly 500 points preserving boundaries',
      () {
        final points = List.generate(
          1000,
          (i) => CoordinatePoint(x: i.toDouble(), y: math.cos(i * 0.05)),
        );

        final downsampled = ChartDownsampler.downsample(points);

        expect(downsampled.length, 500);
        // First and last points strictly preserved
        expect(downsampled.first.x, 0.0);
        expect(downsampled.first.y, points.first.y);
        expect(downsampled.last.x, 999.0);
        expect(downsampled.last.y, points.last.y);
      },
    );

    test(
      '5,000 points dataset is downsampled to exactly 500 points in linear time',
      () {
        final points = List.generate(
          5000,
          (i) => CoordinatePoint(x: i.toDouble(), y: (i * 0.01) * (i * 0.01)),
        );

        final stopwatch = Stopwatch()..start();
        final downsampled = ChartDownsampler.downsample(points);
        stopwatch.stop();

        expect(downsampled.length, 500);
        expect(downsampled.first.x, 0.0);
        expect(downsampled.last.x, 4999.0);
        // Downsampling 5000 points should execute in well under 100ms
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      },
    );

    test('LTTB downsampling preserves prominent extrema and peaks', () {
      // Create 1,000 points with a flat line except for a sharp spike at index 500
      final points = List.generate(
        1000,
        (i) => CoordinatePoint(x: i.toDouble(), y: i == 500 ? 100.0 : 1.0),
      );

      final downsampled = ChartDownsampler.downsample(points);

      expect(downsampled.length, 500);
      // The sharp spike at y = 100 must be retained in the sampled set
      final hasPeak = downsampled.any((p) => p.y == 100.0);
      expect(hasPeak, isTrue);
    });

    test(
      'toOptimizedSpots filters invalid points and downsamples large datasets',
      () {
        final points = <CoordinatePoint>[
          const CoordinatePoint(x: double.nan, y: 0),
          ...List.generate(
            1200,
            (i) => CoordinatePoint(x: i.toDouble(), y: i * 2.0),
          ),
          const CoordinatePoint(x: 1201, y: double.infinity),
        ];

        final spots = ChartDownsampler.toOptimizedSpots(points);

        expect(spots.length, 500);
        expect(spots.every((s) => s.x.isFinite && s.y.isFinite), isTrue);
        expect(spots.first.x, 0.0);
        expect(spots.last.x, 1199.0);
      },
    );

    test('domain SolverGraphData is not mutated by downsampling', () {
      final rawPoints = List.generate(
        1000,
        (i) => CoordinatePoint(x: i.toDouble(), y: i.toDouble()),
      );
      final curveData = CurveGraphData(
        points: rawPoints,
        label: 'ODE Trajectory',
      );

      final spots = ChartDownsampler.toOptimizedSpots(curveData.points);

      expect(spots.length, 500);
      // Original domain data remains 1000 points
      expect(curveData.points.length, 1000);
      expect(curveData.minX, 0.0);
      expect(curveData.maxX, 999.0);
    });
  });

  group('Phase 3e — Large Dataset Widget Rendering (100 to 5,000 Points)', () {
    testWidgets(
      'CurveChartRenderer renders 100, 500, 1000, and 5000 points safely',
      (
        tester,
      ) async {
        for (final count in [100, 500, 1000, 5000]) {
          final points = List.generate(
            count,
            (i) => CoordinatePoint(
              x: i.toDouble(),
              y: math.sin(i * 0.01) * 10.0,
            ),
          );
          final data = CurveGraphData(points: points, label: 'Dense Curve');

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CurveChartRenderer(data: data),
              ),
            ),
          );

          expect(find.byType(LineChart), findsOneWidget);
          expect(find.byType(RepaintBoundary), findsWidgets);
        }
      },
    );

    testWidgets(
      'InterpolationChartRenderer renders 1,000 and 5,000 sampled curve points',
      (
        tester,
      ) async {
        for (final count in [1000, 5000]) {
          final originalPoints = List.generate(
            10,
            (i) => CoordinatePoint(x: i * 10, y: (i * 10.0) % 7.0),
          );
          final sampledCurve = List.generate(
            count,
            (i) => CoordinatePoint(
              x: i * (100.0 / count),
              y: math.sin(i * 0.05),
            ),
          );
          final data = InterpolationGraphData(
            originalPoints: originalPoints,
            sampledCurve: sampledCurve,
            predictedPoint: const CoordinatePoint(x: 45, y: 3.5),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: InterpolationChartRenderer(data: data),
              ),
            ),
          );

          expect(find.byType(LineChart), findsOneWidget);
        }
      },
    );

    testWidgets(
      'DifferentiationChartRenderer renders large 1,000 point tabular dataset',
      (
        tester,
      ) async {
        final originalPoints = List.generate(
          1000,
          (i) => CoordinatePoint(x: i.toDouble(), y: i * 0.5),
        );
        final stencilPoints = [
          const CoordinatePoint(x: 499, y: 249.5),
          const CoordinatePoint(x: 500, y: 250),
          const CoordinatePoint(x: 501, y: 250.5),
        ];
        final data = DifferentiationGraphData(
          originalPoints: originalPoints,
          stencilPoints: stencilPoints,
          derivativePoint: const CoordinatePoint(x: 500, y: 0.5),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DifferentiationChartRenderer(data: data),
            ),
          ),
        );

        expect(find.byType(LineChart), findsOneWidget);
      },
    );

    testWidgets(
      'SolverChartView displays original point count in legend while rendering safely',
      (
        tester,
      ) async {
        final points = List.generate(
          2500,
          (i) => CoordinatePoint(x: i.toDouble(), y: math.sqrt(i)),
        );
        final data = CurveGraphData(
          points: points,
          label: 'High-Res Trajectory',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SolverChartView(graphData: data),
            ),
          ),
        );

        expect(find.text('2500 points'), findsOneWidget);
        expect(
          find.byKey(const Key('solver_chart_view_repaint_boundary')),
          findsOneWidget,
        );
        expect(find.byType(LineChart), findsOneWidget);
      },
    );

    testWidgets(
      'SolverResultView renders 5,000-point graph isolated from result metadata',
      (
        tester,
      ) async {
        final points = List.generate(
          5000,
          (i) => CoordinatePoint(x: i.toDouble(), y: math.sin(i * 0.02)),
        );
        final result = SolverResult(
          method: 'RK4 ODE Solver',
          status: 'converged',
          executionTimeMs: 12,
          typedGraphData: CurveGraphData(
            points: points,
            label: 'Solution Path',
          ),
          finalAnswer: const {
            'steps': 5000,
            'iterations': 5000,
            'finalY': 0.85,
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SolverResultView(result: result),
              ),
            ),
          ),
        );

        expect(find.text('Method: RK4 ODE Solver'), findsOneWidget);
        expect(find.text('Time: 12 ms'), findsOneWidget);
        expect(find.text('5000 points'), findsOneWidget);
        expect(find.byType(SolverChartView), findsOneWidget);
        expect(find.byType(LineChart), findsOneWidget);
      },
    );
  });
}

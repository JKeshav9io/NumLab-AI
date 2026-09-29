import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_graph_data_model.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_result_model.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_category.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_registry.dart';

void main() {
  group('Category-Specific Graph Validation - Registry & Backend Alignment', () {
    test('verifies total solver registry count and categorisation', () {
      expect(SolverMethodRegistry.all.length, 27);

      final rootFinding = SolverMethodRegistry.getByCategory(
        SolverCategory.rootFinding,
      );
      final linearSystems = SolverMethodRegistry.getByCategory(
        SolverCategory.linearAlgebra,
      );
      final interpolation = SolverMethodRegistry.getByCategory(
        SolverCategory.interpolation,
      );
      final ode = SolverMethodRegistry.getByCategory(SolverCategory.ode);
      final integration = SolverMethodRegistry.getByCategory(
        SolverCategory.integration,
      );
      final differentiation = SolverMethodRegistry.getByCategory(
        SolverCategory.differentiation,
      );

      expect(rootFinding.length, 4);
      expect(linearSystems.length, 3);
      expect(interpolation.length, 7);
      expect(ode.length, 4);
      expect(integration.length, 4);
      expect(differentiation.length, 5);
    });

    // 1. Root Finding (4 solvers: bisection, newton-raphson, secant, regula-falsi)
    test(
      '1. Root Finding: produces valid CurveGraphData from f(x) samples',
      () {
        final backendPayload = <Map<String, dynamic>>[
          {'x': 1.0, 'y': -2.0},
          {'x': 1.5, 'y': -0.375},
          {'x': 2.0, 'y': 2.0},
        ];

        final graphData = SolverGraphDataModel.fromDynamic(backendPayload);
        expect(graphData, isA<CurveGraphData>());
        final curve = graphData! as CurveGraphData;
        expect(curve.points.length, 3);
        expect(curve.minX, 1.0);
        expect(curve.maxX, 2.0);
        expect(curve.minY, -2.0);
        expect(curve.maxY, 2.0);
      },
    );

    // 2. ODE Trajectory (4 solvers: euler, heun, rk4, milne)
    test(
      '2. ODEs: produces valid CurveGraphData for trajectory steps (x_n, y_n)',
      () {
        final backendPayload = <Map<String, dynamic>>[
          {'x': 0.0, 'y': 1.0},
          {'x': 0.1, 'y': 1.1},
          {'x': 0.2, 'y': 1.221},
          {'x': 0.3, 'y': 1.3552},
        ];

        final graphData = SolverGraphDataModel.fromDynamic(backendPayload);
        expect(graphData, isA<CurveGraphData>());
        final curve = graphData! as CurveGraphData;
        expect(curve.points.length, 4);
        expect(curve.points.first.x, 0.0);
        expect(curve.points.first.y, 1.0);
        expect(curve.points.last.x, 0.3);
        expect(curve.points.last.y, 1.3552);
      },
    );

    // 3. Numerical Integration (4 solvers: trapezoidal, simpson13, simpson38, gauss-legendre)
    test(
      '3. Numerical Integration: produces valid CurveGraphData for integrand',
      () {
        final backendPayload = <Map<String, dynamic>>[
          {'x': 0.0, 'y': 0.0},
          {'x': 0.5, 'y': 0.25},
          {'x': 1.0, 'y': 1.0},
        ];

        final graphData = SolverGraphDataModel.fromDynamic(backendPayload);
        expect(graphData, isA<CurveGraphData>());
        final curve = graphData! as CurveGraphData;
        expect(curve.points.length, 3);
        expect(curve.minX, 0.0);
        expect(curve.maxX, 1.0);
      },
    );

    // 4. Function Differentiation (functionFiniteDifference)
    test('4. Function Differentiation: produces valid CurveGraphData', () {
      final backendPayload = <Map<String, dynamic>>[
        {'x': 1.9, 'y': 3.61},
        {'x': 2.0, 'y': 4.0},
        {'x': 2.1, 'y': 4.41},
      ];

      final graphData = SolverGraphDataModel.fromDynamic(backendPayload);
      expect(graphData, isA<CurveGraphData>());
      final curve = graphData! as CurveGraphData;
      expect(curve.points.length, 3);
      expect(curve.points[1].x, 2.0);
      expect(curve.points[1].y, 4.0);
    });

    // 5. Interpolation (7 solvers: lagrange, newtonDividedDifference, newtonForward, newtonBackward, centralDifference, naturalCubicSpline, quadratic)
    test(
      '5. Interpolation: produces InterpolationGraphData with multi-series',
      () {
        final backendPayload = <String, dynamic>{
          'originalPoints': <Map<String, dynamic>>[
            {'x': 1, 'y': 1},
            {'x': 2, 'y': 4},
            {'x': 3, 'y': 9},
          ],
          'sampledCurve': <Map<String, dynamic>>[
            {'x': 1.0, 'y': 1.0},
            {'x': 1.5, 'y': 2.25},
            {'x': 2.0, 'y': 4.0},
            {'x': 2.5, 'y': 6.25},
            {'x': 3.0, 'y': 9.0},
          ],
          'predictedPoint': {'x': 2.5, 'y': 6.25},
        };

        final graphData = SolverGraphDataModel.fromDynamic(backendPayload);
        expect(graphData, isA<InterpolationGraphData>());
        final interp = graphData! as InterpolationGraphData;
        expect(interp.originalPoints.length, 3);
        expect(interp.sampledCurve.length, 5);
        expect(interp.predictedPoint, isNotNull);
        expect(interp.predictedPoint!.x, 2.5);
        expect(interp.predictedPoint!.y, 6.25);
        expect(interp.allPoints.length, 9);
        expect(interp.minX, 1.0);
        expect(interp.maxX, 3.0);
      },
    );

    // 6. Tabular Differentiation (4 solvers: forward, backward, central tabular, lagrange tabular)
    test(
      '6. Tabular Differentiation: produces DifferentiationGraphData with stencils',
      () {
        final backendPayload = <String, dynamic>{
          'originalPoints': <Map<String, dynamic>>[
            {'x': 0, 'y': 1},
            {'x': 1, 'y': 3},
            {'x': 2, 'y': 9},
          ],
          'stencilPoints': <Map<String, dynamic>>[
            {'x': 1, 'y': 3},
            {'x': 2, 'y': 9},
          ],
          'derivativePoint': {'x': 1.0, 'derivative': 6.0},
        };

        final graphData = SolverGraphDataModel.fromDynamic(backendPayload);
        expect(graphData, isA<DifferentiationGraphData>());
        final diff = graphData! as DifferentiationGraphData;
        expect(diff.originalPoints.length, 3);
        expect(diff.stencilPoints.length, 2);
        expect(diff.derivativePoint, isNotNull);
        expect(diff.derivativePoint!.x, 1.0);
        expect(diff.derivativePoint!.y, 6.0);
        expect(diff.derivativeValue, 6.0);
      },
    );

    // 7. Linear Algebra / No-Graph Solvers (3 solvers: gaussElimination, jacobi, gaussSeidel)
    test('7. Linear Algebra: intentionally empty graphData returns null', () {
      // Backend returns empty list for linear systems
      final emptyListPayload = <dynamic>[];
      expect(SolverGraphDataModel.fromDynamic(emptyListPayload), isNull);

      // Model parsed from backend response
      final model = SolverResultModel.fromJson(const {
        'method': 'gauss-elimination',
        'status': 'converged',
        'graphData': <dynamic>[],
        'finalAnswer': {
          'solution': [1.0, 2.0, 3.0],
        },
      });

      expect(model.typedGraphData, isNull);
      expect(model.hasGraphData, isFalse);
    });

    // 8. Malformed & Unsupported Payloads
    test(
      '8. Malformed Payloads: 2D matrix rows (length 3+) are rejected as coordinates',
      () {
        final matrixPayload = <dynamic>[
          [1.0, 2.0, 3.0],
          [4.0, 5.0, 6.0],
          [7.0, 8.0, 9.0],
        ];

        expect(SolverGraphDataModel.fromDynamic(matrixPayload), isNull);
      },
    );

    test(
      '8. Malformed Payloads: scalar numbers array rejected as graph data',
      () {
        final scalarArray = <dynamic>[1.0, 2.0, 3.0, 4.0];
        expect(SolverGraphDataModel.fromDynamic(scalarArray), isNull);
      },
    );

    test(
      '8. Malformed Payloads: random dictionary without graph keys rejected',
      () {
        final randomDict = <String, dynamic>{
          'matrix': [
            [1, 0],
            [0, 1],
          ],
          'determinant': 1.0,
          'title': 'Identity Matrix',
        };

        expect(SolverGraphDataModel.fromDynamic(randomDict), isNull);
      },
    );

    test(
      '8. Malformed Payloads: filters non-finite (NaN, Infinity) coordinates',
      () {
        final nonFinitePayload = <Map<String, dynamic>>[
          {'x': 0.0, 'y': 1.0},
          {'x': double.nan, 'y': 2.0},
          {'x': 1.0, 'y': double.infinity},
          {'x': 2.0, 'y': -double.infinity},
          {'x': 3.0, 'y': 9.0},
        ];

        final graphData = SolverGraphDataModel.fromDynamic(nonFinitePayload);
        expect(graphData, isA<CurveGraphData>());
        final curve = graphData! as CurveGraphData;
        expect(curve.points.length, 2);
        expect(curve.points[0].x, 0.0);
        expect(curve.points[0].y, 1.0);
        expect(curve.points[1].x, 3.0);
        expect(curve.points[1].y, 9.0);
      },
    );
  });
}

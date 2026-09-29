import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_graph_data_model.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';

void main() {
  group('CoordinatePoint parsing & validation', () {
    test('parses numeric map with x and y', () {
      final point = CoordinatePoint.tryParse({
        'x': 1.5,
        'y': 2.75,
        'label': 'root',
      });
      expect(point, isNotNull);
      expect(point!.x, 1.5);
      expect(point.y, 2.75);
      expect(point.label, 'root');
      expect(point.isValid, isTrue);
    });

    test('parses stringified numbers', () {
      final point = CoordinatePoint.tryParse({'x': '3.14', 'y': '-0.5'});
      expect(point, isNotNull);
      expect(point!.x, 3.14);
      expect(point.y, -0.5);
      expect(point.isValid, isTrue);
    });

    test('parses 2-element numeric list', () {
      final point = CoordinatePoint.tryParse(<num>[4, 5], defaultLabel: 'node');
      expect(point, isNotNull);
      expect(point!.x, 4);
      expect(point.y, 5);
      expect(point.label, 'node');
    });

    test('parses derivative keys', () {
      final point = CoordinatePoint.tryParse({'x': 1, 'derivative': 4.2});
      expect(point, isNotNull);
      expect(point!.x, 1);
      expect(point.y, 4.2);
    });

    test('rejects non-finite, NaN, and malformed inputs', () {
      expect(CoordinatePoint.tryParse(null), isNull);
      expect(CoordinatePoint.tryParse('invalid'), isNull);
      expect(CoordinatePoint.tryParse(123), isNull);
      expect(
        CoordinatePoint.tryParse({'x': double.infinity, 'y': 1}),
        isNull,
      );
      expect(CoordinatePoint.tryParse({'x': 1, 'y': double.nan}), isNull);
      expect(CoordinatePoint.tryParse({'x': 'not_a_num', 'y': 2}), isNull);
      expect(CoordinatePoint.tryParse({'x': 1}), isNull);
      expect(CoordinatePoint.tryParse(<dynamic>[]), isNull);
      expect(CoordinatePoint.tryParse(<dynamic>[1]), isNull);
    });

    test('equality and props verification', () {
      const p1 = CoordinatePoint(x: 1, y: 2, label: 'a');
      const p2 = CoordinatePoint(x: 1, y: 2, label: 'a');
      const p3 = CoordinatePoint(x: 1, y: 3, label: 'a');

      expect(p1, equals(p2));
      expect(p1, isNot(equals(p3)));
    });
  });

  group('SolverGraphDataModel.fromDynamic — Curve / List Data', () {
    test('parses standard backend curve list', () {
      final raw = <Map<String, dynamic>>[
        {'x': 0, 'y': -2},
        {'x': 1, 'y': -1},
        {'x': 2, 'y': 4},
      ];

      final result = SolverGraphDataModel.fromDynamic(raw);
      expect(result, isA<CurveGraphData>());
      final curve = result! as CurveGraphData;
      expect(curve.points.length, 3);
      expect(curve.points[0].x, 0);
      expect(curve.points[0].y, -2);
      expect(curve.minX, 0);
      expect(curve.maxX, 2);
      expect(curve.minY, -2);
      expect(curve.maxY, 4);
    });

    test(
      'filters out invalid points in a list while preserving valid ones',
      () {
        final raw = <Map<String, dynamic>>[
          {'x': 1, 'y': 2},
          {'x': 'bad', 'y': 3},
          {'x': 2, 'y': double.infinity},
          {'x': 3, 'y': 6},
        ];

        final result = SolverGraphDataModel.fromDynamic(raw);
        expect(result, isA<CurveGraphData>());
        final curve = result! as CurveGraphData;
        expect(curve.points.length, 2);
        expect(curve.points[0].x, 1);
        expect(curve.points[1].x, 3);
      },
    );

    test('returns null when list has only invalid points or is empty', () {
      expect(SolverGraphDataModel.fromDynamic(<dynamic>[]), isNull);
      expect(
        SolverGraphDataModel.fromDynamic(<Map<String, dynamic>>[
          {'x': 'invalid', 'y': 1},
          {'y': 2},
        ]),
        isNull,
      );
    });
  });

  group('SolverGraphDataModel.fromDynamic — Interpolation Data', () {
    test('parses full backend interpolation map structure', () {
      final raw = <String, dynamic>{
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
      };

      final result = SolverGraphDataModel.fromDynamic(raw);
      expect(result, isA<InterpolationGraphData>());
      final interp = result! as InterpolationGraphData;
      expect(interp.originalPoints.length, 2);
      expect(interp.sampledCurve.length, 3);
      expect(interp.predictedPoint, isNotNull);
      expect(interp.predictedPoint!.x, 2);
      expect(interp.predictedPoint!.y, 4.5);
      expect(interp.minX, 1);
      expect(interp.maxX, 3);
      expect(interp.minY, 2);
      expect(interp.maxY, 8);
    });

    test('parses interpolation map without predictedPoint', () {
      final raw = <String, dynamic>{
        'originalPoints': <Map<String, dynamic>>[
          {'x': 0, 'y': 1},
        ],
        'sampledCurve': <Map<String, dynamic>>[
          {'x': 0, 'y': 1},
          {'x': 1, 'y': 3},
        ],
        'predictedPoint': null,
      };

      final result = SolverGraphDataModel.fromDynamic(raw);
      expect(result, isA<InterpolationGraphData>());
      final interp = result! as InterpolationGraphData;
      expect(interp.originalPoints.length, 1);
      expect(interp.sampledCurve.length, 2);
      expect(interp.predictedPoint, isNull);
    });
  });

  group('SolverGraphDataModel.fromDynamic — Differentiation Data', () {
    test('parses tabular differentiation map structure', () {
      final raw = <String, dynamic>{
        'originalPoints': <Map<String, dynamic>>[
          {'x': 1, 'y': 2},
          {'x': 2, 'y': 4},
          {'x': 3, 'y': 9},
        ],
        'stencilPoints': <Map<String, dynamic>>[
          {'x': 2, 'y': 4},
          {'x': 3, 'y': 9},
        ],
        'derivativePoint': {'x': 2.5, 'derivative': 5},
        'derivativeValue': 5,
      };

      final result = SolverGraphDataModel.fromDynamic(raw);
      expect(result, isA<DifferentiationGraphData>());
      final diff = result! as DifferentiationGraphData;
      expect(diff.originalPoints.length, 3);
      expect(diff.stencilPoints.length, 2);
      expect(diff.derivativePoint, isNotNull);
      expect(diff.derivativePoint!.x, 2.5);
      expect(diff.derivativePoint!.y, 5);
      expect(diff.derivativeValue, 5);
      expect(diff.minX, 1);
      expect(diff.maxX, 3);
    });
  });

  group('SolverGraphDataModel.fromDynamic — Edge Cases & Safety', () {
    test('handles null and invalid types gracefully without throwing', () {
      expect(SolverGraphDataModel.fromDynamic(null), isNull);
      expect(SolverGraphDataModel.fromDynamic('random_string'), isNull);
      expect(SolverGraphDataModel.fromDynamic(12345), isNull);
      expect(SolverGraphDataModel.fromDynamic(true), isNull);
      expect(SolverGraphDataModel.fromDynamic(<String, dynamic>{}), isNull);
      expect(
        SolverGraphDataModel.fromDynamic(<String, dynamic>{
          'unrelatedKey': 123,
        }),
        isNull,
      );
    });

    test('parses nested curve list under points or curve key', () {
      final raw = <String, dynamic>{
        'points': <Map<String, dynamic>>[
          {'x': 0, 'y': 0},
          {'x': 1, 'y': 1},
        ],
      };

      final result = SolverGraphDataModel.fromDynamic(raw);
      expect(result, isA<CurveGraphData>());
      final curve = result! as CurveGraphData;
      expect(curve.points.length, 2);
    });

    test('empty domain entities return default bounding box coordinates', () {
      const emptyCurve = CurveGraphData(points: []);
      expect(emptyCurve.isEmpty, isTrue);
      expect(emptyCurve.minX, 0);
      expect(emptyCurve.maxX, 1);
      expect(emptyCurve.minY, 0);
      expect(emptyCurve.maxY, 1);

      const emptyInterp = InterpolationGraphData();
      expect(emptyInterp.isEmpty, isTrue);
      expect(emptyInterp.minX, 0);
      expect(emptyInterp.maxX, 1);

      const emptyDiff = DifferentiationGraphData();
      expect(emptyDiff.isEmpty, isTrue);
      expect(emptyDiff.minX, 0);
      expect(emptyDiff.maxX, 1);
    });
  });
}

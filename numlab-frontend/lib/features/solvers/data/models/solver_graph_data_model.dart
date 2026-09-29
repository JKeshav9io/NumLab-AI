import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';

/// Data parser and serialization helper for backend numerical solver `graphData` payloads.
abstract final class SolverGraphDataModel {
  /// Safely converts raw backend `graphData` of any shape into a typed [SolverGraphData] domain entity.
  ///
  /// Returns `null` if [rawData] is null, empty, malformed, or contains zero valid numeric points.
  /// Never throws an exception.
  static SolverGraphData? fromDynamic(dynamic rawData) {
    if (rawData == null) return null;

    try {
      // 1. Array / List of points (Root Finding, ODE trajectories, Integration, Function Differentiation)
      if (rawData is List) {
        return _parseListToCurve(rawData);
      }

      // 2. Map structures (Interpolation, Tabular Differentiation, or Nested curves)
      if (rawData is Map) {
        return _parseMapToGraphData(rawData);
      }
    } on Object catch (_) {
      // Defensive catch-all to prevent any unexpected payload error from breaking execution.
      return null;
    }

    return null;
  }

  /// Parses a generic list of point maps or coordinate tuples into a [CurveGraphData].
  static CurveGraphData? _parseListToCurve(List<dynamic> list) {
    if (list.isEmpty) return null;

    final validPoints = <CoordinatePoint>[];
    for (final item in list) {
      final point = CoordinatePoint.tryParse(item);
      if (point != null && point.isValid) {
        validPoints.add(point);
      }
    }

    if (validPoints.isEmpty) return null;
    return CurveGraphData(points: List.unmodifiable(validPoints));
  }

  /// Parses a map-based graphData payload into either [InterpolationGraphData],
  /// [DifferentiationGraphData], or [CurveGraphData].
  static SolverGraphData? _parseMapToGraphData(Map<dynamic, dynamic> map) {
    // Check for Tabular Differentiation indicators
    final hasStencil =
        map.containsKey('stencilPoints') ||
        map.containsKey('stencil') ||
        map.containsKey('derivativePoint');
    if (hasStencil) {
      return _parseDifferentiationMap(map);
    }

    // Check for Interpolation indicators
    final hasInterpolation =
        map.containsKey('originalPoints') ||
        map.containsKey('sampledCurve') ||
        map.containsKey('predictedPoint') ||
        map.containsKey('targetPoint');
    if (hasInterpolation) {
      return _parseInterpolationMap(map);
    }

    // Check for nested curve lists under common keys
    final nestedList =
        map['points'] ?? map['curve'] ?? map['data'] ?? map['trajectory'];
    if (nestedList is List) {
      final curve = _parseListToCurve(nestedList);
      if (curve != null) return curve;
    }

    return null;
  }

  static InterpolationGraphData? _parseInterpolationMap(
    Map<dynamic, dynamic> map,
  ) {
    final originalPoints = _parsePointList(
      map['originalPoints'] ?? map['points'],
    );
    final sampledCurve = _parsePointList(map['sampledCurve'] ?? map['curve']);
    final predictedPoint = CoordinatePoint.tryParse(
      map['predictedPoint'] ?? map['targetPoint'],
    );

    if (originalPoints.isEmpty &&
        sampledCurve.isEmpty &&
        predictedPoint == null) {
      return null;
    }

    return InterpolationGraphData(
      originalPoints: List.unmodifiable(originalPoints),
      sampledCurve: List.unmodifiable(sampledCurve),
      predictedPoint: predictedPoint,
    );
  }

  static DifferentiationGraphData? _parseDifferentiationMap(
    Map<dynamic, dynamic> map,
  ) {
    final originalPoints = _parsePointList(
      map['originalPoints'] ?? map['points'],
    );
    final stencilPoints = _parsePointList(
      map['stencilPoints'] ?? map['stencil'],
    );
    final derivativePoint = CoordinatePoint.tryParse(map['derivativePoint']);

    double? derivativeValue;
    final rawDeriv =
        map['derivativeValue'] ??
        map['derivative'] ??
        (map['derivativePoint'] is Map
            ? ((map['derivativePoint'] as Map)['derivative'] ??
                  (map['derivativePoint'] as Map)['y'])
            : null);
    if (rawDeriv != null) {
      if (rawDeriv is num) {
        if (rawDeriv.toDouble().isFinite && !rawDeriv.toDouble().isNaN) {
          derivativeValue = rawDeriv.toDouble();
        }
      } else if (rawDeriv is String) {
        final parsed = double.tryParse(rawDeriv.trim());
        if (parsed != null && parsed.isFinite && !parsed.isNaN) {
          derivativeValue = parsed;
        }
      }
    }

    if (originalPoints.isEmpty &&
        stencilPoints.isEmpty &&
        derivativePoint == null &&
        derivativeValue == null) {
      return null;
    }

    return DifferentiationGraphData(
      originalPoints: List.unmodifiable(originalPoints),
      stencilPoints: List.unmodifiable(stencilPoints),
      derivativePoint: derivativePoint,
      derivativeValue: derivativeValue,
    );
  }

  static List<CoordinatePoint> _parsePointList(dynamic rawList) {
    if (rawList is! List) return const [];
    final points = <CoordinatePoint>[];
    for (final item in rawList) {
      final point = CoordinatePoint.tryParse(item);
      if (point != null && point.isValid) {
        points.add(point);
      }
    }
    return points;
  }
}

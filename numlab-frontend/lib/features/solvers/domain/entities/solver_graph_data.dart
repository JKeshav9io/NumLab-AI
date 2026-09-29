import 'package:equatable/equatable.dart';

/// Represents a single 2D cartesian coordinate point (x, y) with optional label.
class CoordinatePoint extends Equatable {
  const CoordinatePoint({
    required this.x,
    required this.y,
    this.label,
  });

  /// The horizontal coordinate on the X-axis.
  final double x;

  /// The vertical coordinate on the Y-axis.
  final double y;

  /// Optional label or descriptor (e.g. 'root', 'initial_guess', 'stencil').
  final String? label;

  /// Whether both x and y are finite and not NaN.
  bool get isValid => x.isFinite && !x.isNaN && y.isFinite && !y.isNaN;

  /// Safely attempts to parse a [CoordinatePoint] from a dynamic object or map.
  ///
  /// Returns `null` if parsing fails or values are non-finite/NaN.
  static CoordinatePoint? tryParse(dynamic point, {String? defaultLabel}) {
    if (point == null) return null;

    if (point is CoordinatePoint) {
      return point.isValid ? point : null;
    }

    if (point is Map) {
      final rawX = point['x'] ?? point['X'];
      final rawY =
          point['y'] ??
          point['Y'] ??
          point['derivative'] ??
          point['derivativeValue'] ??
          point['value'];
      final rawLabel = point['label'] ?? defaultLabel;

      final parsedX = _parseToDouble(rawX);
      final parsedY = _parseToDouble(rawY);

      if (parsedX != null &&
          parsedY != null &&
          parsedX.isFinite &&
          !parsedX.isNaN &&
          parsedY.isFinite &&
          !parsedY.isNaN) {
        return CoordinatePoint(
          x: parsedX,
          y: parsedY,
          label: rawLabel?.toString(),
        );
      }
    }

    if (point is List && point.length == 2) {
      final parsedX = _parseToDouble(point[0]);
      final parsedY = _parseToDouble(point[1]);

      if (parsedX != null &&
          parsedY != null &&
          parsedX.isFinite &&
          !parsedX.isNaN &&
          parsedY.isFinite &&
          !parsedY.isNaN) {
        return CoordinatePoint(
          x: parsedX,
          y: parsedY,
          label: defaultLabel,
        );
      }
    }

    return null;
  }

  static double? _parseToDouble(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.trim());
    return null;
  }

  @override
  List<Object?> get props => [x, y, label];
}

/// Abstract base domain entity for all graph visualization data.
sealed class SolverGraphData extends Equatable {
  const SolverGraphData();

  /// Whether the graph data contains any valid plot points.
  bool get isEmpty;

  /// Whether the graph data contains at least one valid plot point.
  bool get isNotEmpty => !isEmpty;

  /// Computes the bounding box minimum X across all contained points, or 0.0.
  double get minX;

  /// Computes the bounding box maximum X across all contained points, or 1.0.
  double get maxX;

  /// Computes the bounding box minimum Y across all contained points, or 0.0.
  double get minY;

  /// Computes the bounding box maximum Y across all contained points, or 1.0.
  double get maxY;
}

/// Domain graph data entity representing a single continuous or discrete 2D curve
/// (used by Root-Finding, ODE trajectories, Numerical Integration, and Function Differentiation).
class CurveGraphData extends SolverGraphData {
  const CurveGraphData({
    required this.points,
    this.label,
  });

  /// The series of coordinate points forming the curve.
  final List<CoordinatePoint> points;

  /// Optional label for the curve series.
  final String? label;

  @override
  bool get isEmpty => points.isEmpty;

  @override
  double get minX => _computeBounds().$1;

  @override
  double get maxX => _computeBounds().$2;

  @override
  double get minY => _computeBounds().$3;

  @override
  double get maxY => _computeBounds().$4;

  (double, double, double, double) _computeBounds() {
    if (points.isEmpty) return (0.0, 1.0, 0.0, 1.0);
    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;

    for (final p in points) {
      if (!p.isValid) continue;
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    if (minX.isInfinite) {
      return (0.0, 1.0, 0.0, 1.0);
    }
    return (minX, maxX, minY, maxY);
  }

  @override
  List<Object?> get props => [points, label];
}

/// Domain graph data entity representing multi-series interpolation data
/// (original scatter nodes, dense fitted polynomial curve, and optional target point).
class InterpolationGraphData extends SolverGraphData {
  const InterpolationGraphData({
    this.originalPoints = const [],
    this.sampledCurve = const [],
    this.predictedPoint,
  });

  /// The original discrete dataset points provided as inputs.
  final List<CoordinatePoint> originalPoints;

  /// The dense fitted polynomial / spline interpolation curve.
  final List<CoordinatePoint> sampledCurve;

  /// The evaluated target point (targetX, predictedY) if requested.
  final CoordinatePoint? predictedPoint;

  /// Aggregation of all available points for bounds and validation checks.
  List<CoordinatePoint> get allPoints {
    final list = <CoordinatePoint>[...originalPoints, ...sampledCurve];
    if (predictedPoint != null) {
      list.add(predictedPoint!);
    }
    return list;
  }

  @override
  bool get isEmpty =>
      originalPoints.isEmpty && sampledCurve.isEmpty && predictedPoint == null;

  @override
  double get minX => _computeBounds().$1;

  @override
  double get maxX => _computeBounds().$2;

  @override
  double get minY => _computeBounds().$3;

  @override
  double get maxY => _computeBounds().$4;

  (double, double, double, double) _computeBounds() {
    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;

    for (final p in originalPoints) {
      if (!p.isValid) continue;
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    for (final p in sampledCurve) {
      if (!p.isValid) continue;
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    if (predictedPoint != null && predictedPoint!.isValid) {
      final p = predictedPoint!;
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    if (minX.isInfinite) {
      return (0.0, 1.0, 0.0, 1.0);
    }
    return (minX, maxX, minY, maxY);
  }

  @override
  List<Object?> get props => [originalPoints, sampledCurve, predictedPoint];
}

/// Domain graph data entity representing numerical differentiation data
/// (input discrete points, stencil points used in difference quotient, and target derivative point).
class DifferentiationGraphData extends SolverGraphData {
  const DifferentiationGraphData({
    this.originalPoints = const [],
    this.stencilPoints = const [],
    this.derivativePoint,
    this.derivativeValue,
  });

  /// The input tabular discrete dataset points.
  final List<CoordinatePoint> originalPoints;

  /// The specific points utilized by the numerical stencil.
  final List<CoordinatePoint> stencilPoints;

  /// The point where derivative was evaluated (x: targetX, y: derivative).
  final CoordinatePoint? derivativePoint;

  /// The computed derivative value.
  final double? derivativeValue;

  /// Aggregation of all available points for bounds.
  List<CoordinatePoint> get allPoints {
    final list = <CoordinatePoint>[...originalPoints, ...stencilPoints];
    if (derivativePoint != null) {
      list.add(derivativePoint!);
    }
    return list;
  }

  @override
  bool get isEmpty =>
      originalPoints.isEmpty &&
      stencilPoints.isEmpty &&
      derivativePoint == null;

  @override
  double get minX => _computeBounds().$1;

  @override
  double get maxX => _computeBounds().$2;

  @override
  double get minY => _computeBounds().$3;

  @override
  double get maxY => _computeBounds().$4;

  (double, double, double, double) _computeBounds() {
    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;

    for (final p in originalPoints) {
      if (!p.isValid) continue;
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    for (final p in stencilPoints) {
      if (!p.isValid) continue;
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    if (derivativePoint != null && derivativePoint!.isValid) {
      final p = derivativePoint!;
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    if (minX.isInfinite) {
      return (0.0, 1.0, 0.0, 1.0);
    }
    return (minX, maxX, minY, maxY);
  }

  @override
  List<Object?> get props => [
    originalPoints,
    stencilPoints,
    derivativePoint,
    derivativeValue,
  ];
}

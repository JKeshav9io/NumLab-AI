import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_graph_data.dart';

/// Performance optimization utility for chart point density reduction.
///
/// Implements the Largest-Triangle-Three-Buckets (LTTB) downsampling algorithm,
/// which preserves visual peaks, valleys, and curve geometry while reducing point
/// count to maintain smooth rendering and interactive performance on large datasets (500+ points).
abstract final class ChartDownsampler {
  /// Default point count threshold for chart visualization.
  static const int defaultMaxPoints = 500;

  /// Downsamples a list of [CoordinatePoint] to at most [maxPoints] using
  /// the Largest Triangle Three Buckets (LTTB) algorithm.
  ///
  /// Guarantees:
  /// - If points length <= [maxPoints], returns original points unmodified.
  /// - Strictly preserves the first and last points of the dataset.
  /// - Preserves key peaks, valleys, and overall curve geometry.
  /// - Deterministic and linear O(N) runtime complexity.
  /// - Does not mutate the original input list or domain entities.
  static List<CoordinatePoint> downsample(
    List<CoordinatePoint> points, {
    int maxPoints = defaultMaxPoints,
  }) {
    if (points.length <= maxPoints || maxPoints < 3) {
      return points;
    }

    final sampled = <CoordinatePoint>[];
    final numPoints = points.length;
    final bucketSize = (numPoints - 2) / (maxPoints - 2);

    // 1. Always include the first point
    var aIndex = 0;
    sampled.add(points[aIndex]);

    for (var i = 0; i < maxPoints - 2; i++) {
      // 2. Calculate average coordinate for the next bucket (i + 1)
      final nextBucketStart = ((i + 1) * bucketSize).floor() + 1;
      final nextBucketEnd = math.min(
        ((i + 2) * bucketSize).floor() + 1,
        numPoints,
      );

      var avgX = 0.0;
      var avgY = 0.0;
      var nextCount = 0;

      for (var j = nextBucketStart; j < nextBucketEnd; j++) {
        avgX += points[j].x;
        avgY += points[j].y;
        nextCount++;
      }

      if (nextCount > 0) {
        avgX /= nextCount;
        avgY /= nextCount;
      } else {
        avgX = points[numPoints - 1].x;
        avgY = points[numPoints - 1].y;
      }

      // 3. Find candidate in current bucket that maximizes triangle area with A and next bucket center
      final currentBucketStart = (i * bucketSize).floor() + 1;
      final currentBucketEnd = math.min(
        ((i + 1) * bucketSize).floor() + 1,
        numPoints,
      );

      final pointA = points[aIndex];
      var maxArea = -1.0;
      var maxAreaIndex = currentBucketStart;

      for (var j = currentBucketStart; j < currentBucketEnd; j++) {
        final pointCandidate = points[j];
        // Triangle area = 0.5 * |(Ax - avgX)*(y - Ay) - (Ax - x)*(avgY - Ay)|
        final area =
            ((pointA.x - avgX) * (pointCandidate.y - pointA.y) -
                    (pointA.x - pointCandidate.x) * (avgY - pointA.y))
                .abs() *
            0.5;

        if (area > maxArea) {
          maxArea = area;
          maxAreaIndex = j;
        }
      }

      sampled.add(points[maxAreaIndex]);
      aIndex = maxAreaIndex;
    }

    // 4. Always include the last point
    sampled.add(points[numPoints - 1]);

    return sampled;
  }

  /// Converts a list of [CoordinatePoint] into optimized [FlSpot] objects for fl_chart.
  ///
  /// Filters out non-finite or invalid points, applies LTTB downsampling when
  /// point count exceeds [maxPoints], and returns the final spots.
  static List<FlSpot> toOptimizedSpots(
    List<CoordinatePoint> points, {
    int maxPoints = defaultMaxPoints,
  }) {
    if (points.isEmpty) return const [];

    final valid = points.where((p) => p.isValid).toList(growable: false);
    if (valid.isEmpty) return const [];

    if (valid.length <= maxPoints || maxPoints < 3) {
      return valid.map((p) => FlSpot(p.x, p.y)).toList(growable: false);
    }

    final sampled = downsample(valid, maxPoints: maxPoints);
    return sampled.map((p) => FlSpot(p.x, p.y)).toList(growable: false);
  }
}

'use strict';

const { AppError, errorCodes } = require('../../../common/errors');

const DEFAULT_GRAPH_POINT_COUNT = 80;
const NEAR_ZERO_THRESHOLD = 1e-12;

function round(value, decimals = 10) {
  const rounded = Number.parseFloat(value.toFixed(decimals));
  return Object.is(rounded, -0) ? 0 : rounded;
}

function roundPoint(point) {
  return {
    x: round(point.x),
    y: round(point.y),
  };
}

function roundPoints(points) {
  return points.map(roundPoint);
}

function sortPoints(points) {
  return points
    .map((point) => ({ x: point.x, y: point.y }))
    .sort((a, b) => a.x - b.x);
}

function buildInput(points, targetX) {
  return {
    points: roundPoints(points),
    targetX: round(targetX),
  };
}

function buildResult({ method, input, iterations, finalAnswer, explanation, graphData, warnings, start }) {
  return {
    method,
    status: 'converged',
    input,
    iterations,
    finalAnswer,
    explanation,
    graphData,
    warnings,
    executionTimeMs: Date.now() - start,
  };
}

function buildExplanation(method, steps) {
  return {
    summary: `${method} computed the requested interpolated value from the supplied data points.`,
    steps,
  };
}

function buildFinalAnswer(targetX, predictedY, reason = 'Interpolation completed') {
  return {
    targetX: round(targetX),
    predictedY: round(predictedY),
    converged: true,
    reason,
  };
}

function emptyGraphData() {
  return {
    originalPoints: [],
    sampledCurve: [],
    predictedPoint: null,
  };
}

function buildGraphData(points, targetX, predictedY, evaluateAt) {
  const minX = points[0].x;
  const maxX = points[points.length - 1].x;
  const sampledCurve = [];
  const step = (maxX - minX) / DEFAULT_GRAPH_POINT_COUNT;

  for (let i = 0; i <= DEFAULT_GRAPH_POINT_COUNT; i++) {
    const x = i === DEFAULT_GRAPH_POINT_COUNT ? maxX : minX + step * i;
    sampledCurve.push({
      x: round(x),
      y: round(evaluateAt(x)),
    });
  }

  return {
    originalPoints: roundPoints(points),
    sampledCurve,
    predictedPoint: {
      x: round(targetX),
      y: round(predictedY),
    },
  };
}

function buildRangeWarnings(points, targetX) {
  const warnings = [];
  const minX = points[0].x;
  const maxX = points[points.length - 1].x;

  if (targetX < minX || targetX > maxX) {
    warnings.push('targetX is outside the input point range; result is extrapolation');
  }

  return warnings;
}

function solveLinearSystem(matrix, constants) {
  const a = matrix.map((row) => row.slice());
  const b = constants.slice();
  const n = a.length;

  for (let pivotIndex = 0; pivotIndex < n; pivotIndex++) {
    let maxRow = pivotIndex;

    for (let row = pivotIndex + 1; row < n; row++) {
      if (Math.abs(a[row][pivotIndex]) > Math.abs(a[maxRow][pivotIndex])) {
        maxRow = row;
      }
    }

    if (Math.abs(a[maxRow][pivotIndex]) < NEAR_ZERO_THRESHOLD) {
      throw new AppError(
        'Interpolation system is singular or nearly singular',
        400,
        errorCodes.SOLVER_PRECONDITION_FAILED,
        { pivotIndex }
      );
    }

    if (maxRow !== pivotIndex) {
      [a[pivotIndex], a[maxRow]] = [a[maxRow], a[pivotIndex]];
      [b[pivotIndex], b[maxRow]] = [b[maxRow], b[pivotIndex]];
    }

    for (let row = pivotIndex + 1; row < n; row++) {
      const factor = a[row][pivotIndex] / a[pivotIndex][pivotIndex];

      for (let col = pivotIndex; col < n; col++) {
        a[row][col] -= factor * a[pivotIndex][col];
      }
      b[row] -= factor * b[pivotIndex];
    }
  }

  const solution = Array(n).fill(0);

  for (let row = n - 1; row >= 0; row--) {
    let sum = b[row];

    for (let col = row + 1; col < n; col++) {
      sum -= a[row][col] * solution[col];
    }

    if (Math.abs(a[row][row]) < NEAR_ZERO_THRESHOLD) {
      throw new AppError(
        'Interpolation system is singular or nearly singular',
        400,
        errorCodes.SOLVER_PRECONDITION_FAILED,
        { pivotIndex: row }
      );
    }

    solution[row] = sum / a[row][row];
  }

  return solution;
}

module.exports = {
  DEFAULT_GRAPH_POINT_COUNT,
  NEAR_ZERO_THRESHOLD,
  buildExplanation,
  buildFinalAnswer,
  buildGraphData,
  buildInput,
  buildRangeWarnings,
  buildResult,
  emptyGraphData,
  round,
  roundPoint,
  roundPoints,
  solveLinearSystem,
  sortPoints,
};

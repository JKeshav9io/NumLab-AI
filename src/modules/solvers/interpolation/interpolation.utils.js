'use strict';

const { AppError, errorCodes } = require('../../../common/errors');
const {
  DEFAULT_GRAPH_POINT_COUNT,
  EQUAL_SPACING_TOLERANCE,
  INTERPOLATION_NEAR_ZERO_THRESHOLD,
} = require('./interpolation.constants');

const NEAR_ZERO_THRESHOLD = INTERPOLATION_NEAR_ZERO_THRESHOLD;

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

function buildResult({
  method,
  input,
  iterations,
  finalAnswer,
  explanation,
  graphData,
  warnings,
  start,
  extra = {},
}) {
  return {
    method,
    status: 'converged',
    input,
    iterations,
    ...extra,
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

function factorial(value) {
  let result = 1;

  for (let number = 2; number <= value; number++) {
    result *= number;
  }

  return result;
}

function getEqualSpacing(points) {
  if (points.length < 2) {
    return 0;
  }

  return points[1].x - points[0].x;
}

function isEquallySpaced(points, tolerance = EQUAL_SPACING_TOLERANCE) {
  if (points.length < 3) {
    return true;
  }

  const spacing = getEqualSpacing(points);

  return points.every((point, index) => {
    if (index === 0) {
      return true;
    }

    const currentSpacing = point.x - points[index - 1].x;
    return Math.abs(currentSpacing - spacing) <= tolerance;
  });
}

function buildForwardDifferenceMatrix(points) {
  const n = points.length;
  const matrix = Array.from({ length: n }, () => Array(n).fill(null));

  for (let row = 0; row < n; row++) {
    matrix[row][0] = points[row].y;
  }

  for (let order = 1; order < n; order++) {
    for (let row = 0; row < n - order; row++) {
      matrix[row][order] = matrix[row + 1][order - 1] - matrix[row][order - 1];
    }
  }

  return matrix;
}

function buildDifferenceTable(points, matrix) {
  return points.map((point, rowIndex) => {
    const differences = {};

    for (let order = 1; order < matrix.length - rowIndex; order++) {
      differences[`delta${order}`] = round(matrix[rowIndex][order]);
    }

    return {
      index: rowIndex,
      x: round(point.x),
      y: round(point.y),
      differences,
    };
  });
}

function evaluateNewtonForwardFromMatrix(points, matrix, x) {
  const h = getEqualSpacing(points);
  const p = (x - points[0].x) / h;
  let predictedY = points[0].y;

  for (let order = 1; order < points.length; order++) {
    predictedY += forwardCoefficient(p, order) * matrix[0][order];
  }

  return predictedY;
}

function evaluateNewtonBackwardFromMatrix(points, matrix, x) {
  const h = getEqualSpacing(points);
  const n = points.length;
  const p = (x - points[n - 1].x) / h;
  let predictedY = points[n - 1].y;

  for (let order = 1; order < n; order++) {
    predictedY += backwardCoefficient(p, order) * matrix[n - 1 - order][order];
  }

  return predictedY;
}

function forwardCoefficient(p, order) {
  let product = 1;

  for (let factor = 0; factor < order; factor++) {
    product *= p - factor;
  }

  return product / factorial(order);
}

function backwardCoefficient(p, order) {
  let product = 1;

  for (let factor = 0; factor < order; factor++) {
    product *= p + factor;
  }

  return product / factorial(order);
}

function buildNewtonForwardSteps(points, matrix, targetX) {
  const h = getEqualSpacing(points);
  const p = (targetX - points[0].x) / h;
  const iterations = [
    {
      step: 1,
      phase: 'setup',
      origin: roundPoint(points[0]),
      stepSize: round(h),
      p: round(p),
      formulaTemplate: 'p = (x - x0) / h',
      substitution: `p = (${round(targetX)} - ${round(points[0].x)}) / ${round(h)} = ${round(p)}`,
    },
  ];
  let sum = points[0].y;

  for (let order = 1; order < points.length; order++) {
    const coefficient = forwardCoefficient(p, order);
    const difference = matrix[0][order];
    const contribution = coefficient * difference;
    sum += contribution;

    iterations.push({
      step: iterations.length + 1,
      phase: 'term',
      order,
      coefficient: round(coefficient),
      difference: round(difference),
      termContribution: round(contribution),
      partialSum: round(sum),
      formulaTemplate: 'p(p-1)... / order! * delta^order y0',
      substitution: `${round(coefficient)} * ${round(difference)} = ${round(contribution)}`,
    });
  }

  iterations.push({
    step: iterations.length + 1,
    phase: 'final-sum',
    predictedY: round(sum),
  });

  return iterations;
}

function buildNewtonBackwardSteps(points, matrix, targetX) {
  const h = getEqualSpacing(points);
  const n = points.length;
  const p = (targetX - points[n - 1].x) / h;
  const iterations = [
    {
      step: 1,
      phase: 'setup',
      origin: roundPoint(points[n - 1]),
      stepSize: round(h),
      p: round(p),
      formulaTemplate: 'p = (x - xn) / h',
      substitution: `p = (${round(targetX)} - ${round(points[n - 1].x)}) / ${round(h)} = ${round(p)}`,
    },
  ];
  let sum = points[n - 1].y;

  for (let order = 1; order < n; order++) {
    const coefficient = backwardCoefficient(p, order);
    const difference = matrix[n - 1 - order][order];
    const contribution = coefficient * difference;
    sum += contribution;

    iterations.push({
      step: iterations.length + 1,
      phase: 'term',
      order,
      coefficient: round(coefficient),
      difference: round(difference),
      termContribution: round(contribution),
      partialSum: round(sum),
      formulaTemplate: 'p(p+1)... / order! * nabla^order yn',
      substitution: `${round(coefficient)} * ${round(difference)} = ${round(contribution)}`,
    });
  }

  iterations.push({
    step: iterations.length + 1,
    phase: 'final-sum',
    predictedY: round(sum),
  });

  return iterations;
}

function buildPreferenceWarnings(points, targetX, preferredMethod) {
  const warnings = [];
  const minX = points[0].x;
  const maxX = points[points.length - 1].x;
  const range = maxX - minX;

  if (range === 0) {
    return warnings;
  }

  const relativePosition = (targetX - minX) / range;

  if (preferredMethod === 'newton-forward' && relativePosition > 0.5) {
    warnings.push('Newton Forward is usually preferred near the beginning; targetX is closer to the end');
  }

  if (preferredMethod === 'newton-backward' && relativePosition < 0.5) {
    warnings.push('Newton Backward is usually preferred near the end; targetX is closer to the beginning');
  }

  if (preferredMethod === 'central-difference' && (relativePosition < 0.25 || relativePosition > 0.75)) {
    warnings.push('Central Difference is usually preferred near the middle of the data range');
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
  buildDifferenceTable,
  buildFinalAnswer,
  buildForwardDifferenceMatrix,
  buildGraphData,
  buildInput,
  buildNewtonBackwardSteps,
  buildNewtonForwardSteps,
  buildPreferenceWarnings,
  buildRangeWarnings,
  buildResult,
  emptyGraphData,
  evaluateNewtonBackwardFromMatrix,
  evaluateNewtonForwardFromMatrix,
  factorial,
  forwardCoefficient,
  getEqualSpacing,
  isEquallySpaced,
  round,
  roundPoint,
  roundPoints,
  solveLinearSystem,
  sortPoints,
};

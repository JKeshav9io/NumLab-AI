'use strict';

const {
  buildExplanation,
  buildFinalAnswer,
  buildGraphData,
  buildInput,
  buildRangeWarnings,
  buildResult,
  emptyGraphData,
  round,
  sortPoints,
} = require('./interpolation.utils');

function solveNewtonDividedDifference(params) {
  const start = Date.now();
  const { targetX, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const warnings = buildRangeWarnings(points, targetX);

  if (points.length > 10) {
    warnings.push('High-degree Newton divided difference interpolation may oscillate with more than 10 points');
  }

  const { coefficients, iterations } = buildDividedDifferenceTable(points);
  const predictedY = evaluateNewtonPolynomial(points, coefficients, targetX);

  return buildResult({
    method: 'Newton Divided Difference',
    input: buildInput(points, targetX),
    iterations,
    finalAnswer: {
      ...buildFinalAnswer(targetX, predictedY),
      coefficients: coefficients.map((coefficient) => round(coefficient)),
    },
    explanation: includeExplanation ? buildExplanation('Newton Divided Difference', [
      'Sort the points by x value.',
      'Build the divided difference table one order at a time.',
      'Evaluate the Newton polynomial with the first value from each table order.',
    ]) : null,
    graphData: includeGraphData
      ? buildGraphData(points, targetX, predictedY, (x) => evaluateNewtonPolynomial(points, coefficients, x))
      : emptyGraphData(),
    warnings,
    start,
  });
}

function buildDividedDifferenceTable(points) {
  const n = points.length;
  const table = Array.from({ length: n }, () => Array(n).fill(null));
  const iterations = [];

  for (let row = 0; row < n; row++) {
    table[row][0] = points[row].y;
  }

  for (let order = 1; order < n; order++) {
    for (let row = 0; row < n - order; row++) {
      const numerator = table[row + 1][order - 1] - table[row][order - 1];
      const denominator = points[row + order].x - points[row].x;
      const value = numerator / denominator;
      table[row][order] = value;

      iterations.push({
        order,
        fromIndex: row,
        toIndex: row + order,
        value: round(value),
        formulaTemplate: 'f[x_i,...,x_j] = (f[x_{i+1},...,x_j] - f[x_i,...,x_{j-1}]) / (x_j - x_i)',
        substitution: `(${round(table[row + 1][order - 1])} - ${round(table[row][order - 1])}) / (${round(points[row + order].x)} - ${round(points[row].x)}) = ${round(value)}`,
      });
    }
  }

  return {
    coefficients: table[0].slice(0, n),
    iterations,
  };
}

function evaluateNewtonPolynomial(points, coefficients, x) {
  let result = coefficients[coefficients.length - 1];

  for (let index = coefficients.length - 2; index >= 0; index--) {
    result = result * (x - points[index].x) + coefficients[index];
  }

  return result;
}

module.exports = {
  solveNewtonDividedDifference,
  newtonDividedDifference: solveNewtonDividedDifference,
};

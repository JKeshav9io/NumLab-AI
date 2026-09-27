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
  roundPoint,
  sortPoints,
} = require('./interpolation.utils');

function solveLagrangeInterpolation(params) {
  const start = Date.now();
  const { targetX, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const warnings = buildRangeWarnings(points, targetX);

  if (points.length > 10) {
    warnings.push('High-degree Lagrange interpolation may oscillate with more than 10 points');
  }

  const iterations = points.map((point, index) => {
    const basisValue = computeBasis(points, index, targetX);
    const termContribution = point.y * basisValue;

    return {
      term: index + 1,
      point: roundPoint(point),
      basisValue: round(basisValue),
      termContribution: round(termContribution),
      formulaTemplate: 'y_i * L_i(x)',
      substitution: `Term ${index + 1} = ${round(point.y)} * ${round(basisValue)} = ${round(termContribution)}`,
    };
  });

  const predictedY = evaluateLagrange(points, targetX);

  return buildResult({
    method: 'Lagrange Interpolation',
    input: buildInput(points, targetX),
    iterations,
    finalAnswer: buildFinalAnswer(targetX, predictedY),
    explanation: includeExplanation ? buildExplanation('Lagrange Interpolation', [
      'Build one basis polynomial for each input point.',
      'Multiply each basis value by its matching y value.',
      'Add all term contributions to get the predicted y value.',
    ]) : null,
    graphData: includeGraphData
      ? buildGraphData(points, targetX, predictedY, (x) => evaluateLagrange(points, x))
      : emptyGraphData(),
    warnings,
    start,
  });
}

function evaluateLagrange(points, x) {
  return points.reduce((sum, point, index) => (
    sum + point.y * computeBasis(points, index, x)
  ), 0);
}

function computeBasis(points, index, x) {
  const xi = points[index].x;

  return points.reduce((product, point, pointIndex) => {
    if (pointIndex === index) {
      return product;
    }

    return product * ((x - point.x) / (xi - point.x));
  }, 1);
}

module.exports = {
  solveLagrangeInterpolation,
  lagrangeInterpolation: solveLagrangeInterpolation,
};

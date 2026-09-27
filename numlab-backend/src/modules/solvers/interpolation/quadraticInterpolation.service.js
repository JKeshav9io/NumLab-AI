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
  roundPoints,
  solveLinearSystem,
  sortPoints,
} = require('./interpolation.utils');

function solveQuadraticInterpolation(params) {
  const start = Date.now();
  const { targetX, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const selectedPoints = selectNearestThreePoints(points, targetX);
  const warnings = buildRangeWarnings(points, targetX);
  warnings.push('Quadratic interpolation uses only the 3 nearest points to targetX');

  const coefficients = solveQuadraticCoefficients(selectedPoints);
  const predictedY = evaluateQuadratic(coefficients, targetX);
  const iterations = [
    {
      step: 1,
      phase: 'select-points',
      selectedPoints: roundPoints(selectedPoints),
      description: 'Selected the 3 nearest points to targetX',
    },
    {
      step: 2,
      phase: 'solve-coefficients',
      coefficients: {
        a: round(coefficients.a),
        b: round(coefficients.b),
        c: round(coefficients.c),
      },
      formulaTemplate: 'y = a*x^2 + b*x + c',
      substitution: 'Solved the 3x3 system formed by the selected points',
    },
    {
      step: 3,
      phase: 'evaluate',
      targetX: round(targetX),
      predictedY: round(predictedY),
      formulaTemplate: 'y = a*x^2 + b*x + c',
      substitution: `y = ${round(coefficients.a)}*(${round(targetX)})^2 + ${round(coefficients.b)}*${round(targetX)} + ${round(coefficients.c)} = ${round(predictedY)}`,
    },
  ];

  return buildResult({
    method: 'Quadratic Interpolation',
    input: buildInput(points, targetX),
    iterations,
    finalAnswer: {
      ...buildFinalAnswer(targetX, predictedY),
      coefficients: {
        a: round(coefficients.a),
        b: round(coefficients.b),
        c: round(coefficients.c),
      },
      selectedPoints: roundPoints(selectedPoints),
    },
    explanation: includeExplanation ? buildExplanation('Quadratic Interpolation', [
      'Choose the 3 nearest input points to targetX.',
      'Fit y = a*x^2 + b*x + c through those selected points.',
      'Evaluate the fitted quadratic at targetX.',
    ]) : null,
    graphData: includeGraphData
      ? buildGraphData(points, targetX, predictedY, (x) => evaluateQuadratic(coefficients, x))
      : emptyGraphData(),
    warnings,
    start,
  });
}

function selectNearestThreePoints(points, targetX) {
  return points
    .slice()
    .sort((a, b) => {
      const distanceDifference = Math.abs(a.x - targetX) - Math.abs(b.x - targetX);
      return distanceDifference === 0 ? a.x - b.x : distanceDifference;
    })
    .slice(0, 3)
    .sort((a, b) => a.x - b.x);
}

function solveQuadraticCoefficients(points) {
  const matrix = points.map((point) => [point.x ** 2, point.x, 1]);
  const constants = points.map((point) => point.y);
  const [a, b, c] = solveLinearSystem(matrix, constants);

  return { a, b, c };
}

function evaluateQuadratic(coefficients, x) {
  return coefficients.a * x ** 2 + coefficients.b * x + coefficients.c;
}

module.exports = {
  solveQuadraticInterpolation,
  quadraticInterpolation: solveQuadraticInterpolation,
};

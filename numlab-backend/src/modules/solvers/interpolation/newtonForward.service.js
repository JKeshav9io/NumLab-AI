'use strict';

const {
  buildDifferenceTable,
  buildExplanation,
  buildFinalAnswer,
  buildForwardDifferenceMatrix,
  buildGraphData,
  buildInput,
  buildNewtonForwardSteps,
  buildPreferenceWarnings,
  buildRangeWarnings,
  buildResult,
  emptyGraphData,
  evaluateNewtonForwardFromMatrix,
  getEqualSpacing,
  round,
  sortPoints,
} = require('./interpolation.utils');

function solveNewtonForwardInterpolation(params) {
  const start = Date.now();
  const { targetX, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const matrix = buildForwardDifferenceMatrix(points);
  const differenceTable = buildDifferenceTable(points, matrix);
  const predictedY = evaluateNewtonForwardFromMatrix(points, matrix, targetX);
  const warnings = [
    ...buildRangeWarnings(points, targetX),
    ...buildPreferenceWarnings(points, targetX, 'newton-forward'),
  ];
  const iterations = buildNewtonForwardSteps(points, matrix, targetX);

  return buildResult({
    method: 'Newton Forward Interpolation',
    input: {
      ...buildInput(points, targetX),
      stepSize: round(getEqualSpacing(points)),
    },
    iterations,
    finalAnswer: buildFinalAnswer(targetX, predictedY),
    explanation: includeExplanation ? buildExplanation('Newton Forward Interpolation', [
      'Sort the points and verify equal spacing.',
      'Build the forward difference table.',
      'Use the first point as the origin and evaluate the Newton forward formula.',
    ]) : null,
    graphData: includeGraphData
      ? buildGraphData(points, targetX, predictedY, (x) => evaluateNewtonForwardFromMatrix(points, matrix, x))
      : emptyGraphData(),
    warnings,
    start,
    extra: { differenceTable },
  });
}

module.exports = {
  solveNewtonForwardInterpolation,
  newtonForwardInterpolation: solveNewtonForwardInterpolation,
};

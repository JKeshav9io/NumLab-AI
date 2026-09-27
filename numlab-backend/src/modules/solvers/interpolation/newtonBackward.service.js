'use strict';

const {
  buildDifferenceTable,
  buildExplanation,
  buildFinalAnswer,
  buildForwardDifferenceMatrix,
  buildGraphData,
  buildInput,
  buildNewtonBackwardSteps,
  buildPreferenceWarnings,
  buildRangeWarnings,
  buildResult,
  emptyGraphData,
  evaluateNewtonBackwardFromMatrix,
  getEqualSpacing,
  round,
  sortPoints,
} = require('./interpolation.utils');

function solveNewtonBackwardInterpolation(params) {
  const start = Date.now();
  const { targetX, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const matrix = buildForwardDifferenceMatrix(points);
  const differenceTable = buildDifferenceTable(points, matrix);
  const predictedY = evaluateNewtonBackwardFromMatrix(points, matrix, targetX);
  const warnings = [
    ...buildRangeWarnings(points, targetX),
    ...buildPreferenceWarnings(points, targetX, 'newton-backward'),
  ];
  const iterations = buildNewtonBackwardSteps(points, matrix, targetX);

  return buildResult({
    method: 'Newton Backward Interpolation',
    input: {
      ...buildInput(points, targetX),
      stepSize: round(getEqualSpacing(points)),
    },
    iterations,
    finalAnswer: buildFinalAnswer(targetX, predictedY),
    explanation: includeExplanation ? buildExplanation('Newton Backward Interpolation', [
      'Sort the points and verify equal spacing.',
      'Build the forward difference table.',
      'Use the last point as the origin and evaluate the Newton backward formula.',
    ]) : null,
    graphData: includeGraphData
      ? buildGraphData(points, targetX, predictedY, (x) => evaluateNewtonBackwardFromMatrix(points, matrix, x))
      : emptyGraphData(),
    warnings,
    start,
    extra: { differenceTable },
  });
}

module.exports = {
  solveNewtonBackwardInterpolation,
  newtonBackwardInterpolation: solveNewtonBackwardInterpolation,
};

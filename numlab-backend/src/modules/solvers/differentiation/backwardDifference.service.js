'use strict';

const {
  buildExplanation,
  buildFinalAnswer,
  buildResult,
  buildTabularGraphData,
  buildTabularInput,
  getEqualSpacing,
  requirePoint,
  round,
  sortPoints,
} = require('./differentiation.utils');

function solveBackwardDifference(params) {
  const start = Date.now();
  const { targetX, exactDerivative, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const h = getEqualSpacing(points);
  const previous = requirePoint(points, targetX - h, 'previous');
  const current = requirePoint(points, targetX, 'target');
  const derivative = (current.y - previous.y) / h;
  const iterations = [
    {
      step: 1,
      x: round(targetX),
      h: round(h),
      fXMinusH: round(previous.y),
      fX: round(current.y),
      derivative: round(derivative),
      formulaTemplate: "f'(x) = (f(x) - f(x - h)) / h",
      substitution: `f'(${round(targetX)}) = (${round(current.y)} - ${round(previous.y)}) / ${round(h)} = ${round(derivative)}`,
    },
  ];

  return buildResult({
    method: 'Backward Difference',
    input: buildTabularInput(params, points),
    iterations,
    finalAnswer: buildFinalAnswer(derivative, exactDerivative, 'Completed backward difference formula'),
    explanation: includeExplanation ? buildExplanation('Backward Difference', [
      'Use the previous equally spaced point and the point at targetX.',
      'Subtract f(x - h) from f(x).',
      'Divide the difference by h.',
    ]) : null,
    graphData: includeGraphData ? buildTabularGraphData(points, targetX, derivative, [previous, current]) : [],
    warnings: [],
    start,
  });
}

module.exports = {
  solveBackwardDifference,
  backwardDifference: solveBackwardDifference,
};

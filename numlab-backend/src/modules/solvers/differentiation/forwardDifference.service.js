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

function solveForwardDifference(params) {
  const start = Date.now();
  const { targetX, exactDerivative, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const h = getEqualSpacing(points);
  const current = requirePoint(points, targetX, 'target');
  const next = requirePoint(points, targetX + h, 'next');
  const derivative = (next.y - current.y) / h;
  const iterations = [
    {
      step: 1,
      x: round(targetX),
      h: round(h),
      fX: round(current.y),
      fXPlusH: round(next.y),
      derivative: round(derivative),
      formulaTemplate: "f'(x) = (f(x + h) - f(x)) / h",
      substitution: `f'(${round(targetX)}) = (${round(next.y)} - ${round(current.y)}) / ${round(h)} = ${round(derivative)}`,
    },
  ];

  return buildResult({
    method: 'Forward Difference',
    input: buildTabularInput(params, points),
    iterations,
    finalAnswer: buildFinalAnswer(derivative, exactDerivative, 'Completed forward difference formula'),
    explanation: includeExplanation ? buildExplanation('Forward Difference', [
      'Use the point at targetX and the next equally spaced point.',
      'Subtract f(x) from f(x + h).',
      'Divide the difference by h.',
    ]) : null,
    graphData: includeGraphData ? buildTabularGraphData(points, targetX, derivative, [current, next]) : [],
    warnings: [],
    start,
  });
}

module.exports = {
  solveForwardDifference,
  forwardDifference: solveForwardDifference,
};

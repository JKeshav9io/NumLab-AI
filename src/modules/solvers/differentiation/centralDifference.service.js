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

function solveCentralDifference(params) {
  const start = Date.now();
  const { targetX, exactDerivative, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const h = getEqualSpacing(points);
  const previous = requirePoint(points, targetX - h, 'previous');
  const next = requirePoint(points, targetX + h, 'next');
  const derivative = (next.y - previous.y) / (2 * h);
  const iterations = [
    {
      step: 1,
      x: round(targetX),
      h: round(h),
      fXMinusH: round(previous.y),
      fXPlusH: round(next.y),
      derivative: round(derivative),
      formulaTemplate: "f'(x) = (f(x + h) - f(x - h)) / (2h)",
      substitution: `f'(${round(targetX)}) = (${round(next.y)} - ${round(previous.y)}) / (2 * ${round(h)}) = ${round(derivative)}`,
    },
  ];

  return buildResult({
    method: 'Central Difference',
    input: buildTabularInput(params, points),
    iterations,
    finalAnswer: buildFinalAnswer(derivative, exactDerivative, 'Completed central difference formula'),
    explanation: includeExplanation ? buildExplanation('Central Difference', [
      'Use equally spaced points on both sides of targetX.',
      'Subtract f(x - h) from f(x + h).',
      'Divide the difference by 2h.',
    ]) : null,
    graphData: includeGraphData ? buildTabularGraphData(points, targetX, derivative, [previous, next]) : [],
    warnings: [],
    start,
  });
}

module.exports = {
  solveCentralDifference,
  centralDifference: solveCentralDifference,
};

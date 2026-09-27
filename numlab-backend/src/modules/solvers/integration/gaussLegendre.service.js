'use strict';

const {
  buildExplanation,
  buildFinalAnswer,
  buildGraphData,
  buildInput,
  buildResult,
  compileIntegrand,
  round,
} = require('./integration.utils');

const GAUSS_LEGENDRE_TABLE = {
  2: [
    { node: -0.5773502691896257, weight: 1 },
    { node: 0.5773502691896257, weight: 1 },
  ],
  3: [
    { node: -0.7745966692414834, weight: 0.5555555555555556 },
    { node: 0, weight: 0.8888888888888888 },
    { node: 0.7745966692414834, weight: 0.5555555555555556 },
  ],
  4: [
    { node: -0.8611363115940526, weight: 0.3478548451374538 },
    { node: -0.3399810435848563, weight: 0.6521451548625461 },
    { node: 0.3399810435848563, weight: 0.6521451548625461 },
    { node: 0.8611363115940526, weight: 0.3478548451374538 },
  ],
  5: [
    { node: -0.906179845938664, weight: 0.2369268850561891 },
    { node: -0.5384693101056831, weight: 0.4786286704993665 },
    { node: 0, weight: 0.5688888888888889 },
    { node: 0.5384693101056831, weight: 0.4786286704993665 },
    { node: 0.906179845938664, weight: 0.2369268850561891 },
  ],
};

function solveGaussLegendre(params) {
  const start = Date.now();
  const {
    lowerBound,
    upperBound,
    points,
    exactValue,
    includeExplanation,
    includeGraphData,
  } = params;
  const { compiled, evaluate } = compileIntegrand(params.equation);
  const halfWidth = (upperBound - lowerBound) / 2;
  const midpoint = (upperBound + lowerBound) / 2;
  let weightedSum = 0;

  const iterations = GAUSS_LEGENDRE_TABLE[points].map((entry, index) => {
    const mappedX = midpoint + halfWidth * entry.node;
    const fX = evaluate(mappedX);
    const weightedValue = entry.weight * fX;

    weightedSum += weightedValue;

    return {
      point: index + 1,
      node: round(entry.node),
      weight: round(entry.weight),
      mappedX: round(mappedX),
      fX: round(fX),
      weightedValue: round(weightedValue),
      formulaTemplate: 'weightedValue = weight * f(mappedX)',
      substitution: `${round(entry.weight)} * f(${round(mappedX)}) = ${round(entry.weight)} * ${round(fX)} = ${round(weightedValue)}`,
    };
  });
  const integral = halfWidth * weightedSum;

  return buildResult({
    method: 'Gauss-Legendre Quadrature',
    input: buildInput(params),
    iterations,
    finalAnswer: buildFinalAnswer(integral, exactValue, `Completed ${points}-point Gauss-Legendre quadrature`),
    explanation: includeExplanation ? buildExplanation('Gauss-Legendre Quadrature', [
      'Map each standard Gauss-Legendre node from [-1, 1] to the requested interval.',
      'Evaluate the integrand at each mapped point.',
      `Multiply the weighted sum by (upperBound - lowerBound) / 2 = ${round(halfWidth)}.`,
    ]) : null,
    graphData: includeGraphData ? buildGraphData(compiled, lowerBound, upperBound) : [],
    warnings: [],
    start,
  });
}

module.exports = {
  GAUSS_LEGENDRE_TABLE,
  solveGaussLegendre,
  gaussLegendre: solveGaussLegendre,
};

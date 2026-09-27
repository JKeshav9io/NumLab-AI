'use strict';

const {
  buildExplanation,
  buildFinalAnswer,
  buildResult,
  buildTabularGraphData,
  buildTabularInput,
  round,
  roundPoint,
  sortPoints,
} = require('./differentiation.utils');

function solveLagrangeDifferentiation(params) {
  const start = Date.now();
  const { targetX, exactDerivative, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  let derivative = 0;
  const iterations = points.map((point, index) => {
    const basisDerivative = computeBasisDerivative(points, index, targetX);
    const termContribution = point.y * basisDerivative;

    derivative += termContribution;

    return {
      term: index + 1,
      point: roundPoint(point),
      basisDerivative: round(basisDerivative),
      termContribution: round(termContribution),
      formulaTemplate: "y_i * L_i'(x)",
      substitution: `Term ${index + 1} = ${round(point.y)} * ${round(basisDerivative)} = ${round(termContribution)}`,
    };
  });

  return buildResult({
    method: 'Lagrange Differentiation',
    input: buildTabularInput(params, points),
    iterations,
    finalAnswer: buildFinalAnswer(derivative, exactDerivative, 'Completed Lagrange derivative formula'),
    explanation: includeExplanation ? buildExplanation('Lagrange Differentiation', [
      'Build the derivative of each Lagrange basis polynomial at targetX.',
      'Multiply each basis derivative by its matching y value.',
      'Add all term contributions to get the derivative estimate.',
    ]) : null,
    graphData: includeGraphData ? buildTabularGraphData(points, targetX, derivative, points) : [],
    warnings: [],
    start,
  });
}

function computeBasisDerivative(points, index, x) {
  const xi = points[index].x;
  let derivative = 0;

  for (let m = 0; m < points.length; m++) {
    if (m === index) {
      continue;
    }

    let product = 1 / (xi - points[m].x);

    for (let j = 0; j < points.length; j++) {
      if (j === index || j === m) {
        continue;
      }

      product *= (x - points[j].x) / (xi - points[j].x);
    }

    derivative += product;
  }

  return derivative;
}

module.exports = {
  computeBasisDerivative,
  solveLagrangeDifferentiation,
  lagrangeDifferentiation: solveLagrangeDifferentiation,
};

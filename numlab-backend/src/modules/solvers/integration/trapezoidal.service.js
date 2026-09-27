'use strict';

const {
  buildExplanation,
  buildFinalAnswer,
  buildGraphData,
  buildInput,
  buildNewtonCotesRows,
  buildResult,
  compileIntegrand,
  round,
} = require('./integration.utils');

function solveTrapezoidal(params) {
  const start = Date.now();
  const {
    lowerBound,
    upperBound,
    subintervals,
    exactValue,
    includeExplanation,
    includeGraphData,
  } = params;
  const { compiled, evaluate } = compileIntegrand(params.equation);
  const h = (upperBound - lowerBound) / subintervals;
  const { iterations, weightedSum } = buildNewtonCotesRows(
    evaluate,
    lowerBound,
    h,
    subintervals,
    getTrapezoidalCoefficient
  );
  const integral = (h / 2) * weightedSum;

  return buildResult({
    method: 'Trapezoidal Rule',
    input: buildInput(params),
    iterations,
    finalAnswer: buildFinalAnswer(integral, exactValue, 'Completed composite trapezoidal rule'),
    explanation: includeExplanation ? buildExplanation('Trapezoidal Rule', [
      'Divide the interval into equal subintervals.',
      'Use coefficient 1 at both endpoints and coefficient 2 at interior points.',
      `Multiply the weighted sum by h / 2, where h = ${round(h)}.`,
    ]) : null,
    graphData: includeGraphData ? buildGraphData(compiled, lowerBound, upperBound) : [],
    warnings: [],
    start,
  });
}

function getTrapezoidalCoefficient(index, subintervals) {
  return index === 0 || index === subintervals ? 1 : 2;
}

module.exports = {
  solveTrapezoidal,
  trapezoidal: solveTrapezoidal,
};

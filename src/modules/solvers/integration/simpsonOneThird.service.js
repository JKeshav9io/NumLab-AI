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

function solveSimpsonOneThird(params) {
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
    getSimpsonOneThirdCoefficient
  );
  const integral = (h / 3) * weightedSum;

  return buildResult({
    method: "Simpson's 1/3 Rule",
    input: buildInput(params),
    iterations,
    finalAnswer: buildFinalAnswer(integral, exactValue, "Completed composite Simpson's 1/3 rule"),
    explanation: includeExplanation ? buildExplanation("Simpson's 1/3 Rule", [
      'Divide the interval into an even number of equal subintervals.',
      'Use endpoint coefficient 1, odd-index coefficient 4, and even interior coefficient 2.',
      `Multiply the weighted sum by h / 3, where h = ${round(h)}.`,
    ]) : null,
    graphData: includeGraphData ? buildGraphData(compiled, lowerBound, upperBound) : [],
    warnings: [],
    start,
  });
}

function getSimpsonOneThirdCoefficient(index, subintervals) {
  if (index === 0 || index === subintervals) {
    return 1;
  }

  return index % 2 === 1 ? 4 : 2;
}

module.exports = {
  solveSimpsonOneThird,
  simpsonOneThird: solveSimpsonOneThird,
};

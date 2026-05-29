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

function solveSimpsonThreeEighth(params) {
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
    getSimpsonThreeEighthCoefficient
  );
  const integral = ((3 * h) / 8) * weightedSum;

  return buildResult({
    method: "Simpson's 3/8 Rule",
    input: buildInput(params),
    iterations,
    finalAnswer: buildFinalAnswer(integral, exactValue, "Completed composite Simpson's 3/8 rule"),
    explanation: includeExplanation ? buildExplanation("Simpson's 3/8 Rule", [
      'Divide the interval into a number of equal subintervals divisible by 3.',
      'Use endpoint coefficient 1, multiples-of-3 interior coefficient 2, and the remaining interior coefficient 3.',
      `Multiply the weighted sum by 3h / 8, where h = ${round(h)}.`,
    ]) : null,
    graphData: includeGraphData ? buildGraphData(compiled, lowerBound, upperBound) : [],
    warnings: [],
    start,
  });
}

function getSimpsonThreeEighthCoefficient(index, subintervals) {
  if (index === 0 || index === subintervals) {
    return 1;
  }

  return index % 3 === 0 ? 2 : 3;
}

module.exports = {
  solveSimpsonThreeEighth,
  simpsonThreeEighth: solveSimpsonThreeEighth,
};

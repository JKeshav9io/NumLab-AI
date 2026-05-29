'use strict';

const { compileExpression, evaluateAt } = require('../../../common/utils/mathParser');

const DEFAULT_GRAPH_POINT_COUNT = 80;

function round(value, decimals = 10) {
  const rounded = Number.parseFloat(value.toFixed(decimals));
  return Object.is(rounded, -0) ? 0 : rounded;
}

function compileIntegrand(equation) {
  const compiled = compileExpression(equation);

  return {
    compiled,
    evaluate(x) {
      return evaluateAt(compiled, { x });
    },
  };
}

function buildInput(params) {
  return {
    equation: params.equation,
    lowerBound: round(params.lowerBound),
    upperBound: round(params.upperBound),
    subintervals: params.subintervals === undefined ? null : params.subintervals,
    points: params.points === undefined ? null : params.points,
    exactValue: params.exactValue === undefined ? null : round(params.exactValue),
  };
}

function buildFinalAnswer(integral, exactValue, reason) {
  const hasExactValue = exactValue !== undefined;
  const absoluteError = hasExactValue ? Math.abs(exactValue - integral) : null;
  const relativeErrorPercent = hasExactValue && exactValue !== 0
    ? (absoluteError / Math.abs(exactValue)) * 100
    : null;

  return {
    integral: round(integral),
    exactValue: hasExactValue ? round(exactValue) : null,
    absoluteError: hasExactValue ? round(absoluteError) : null,
    relativeErrorPercent: relativeErrorPercent === null ? null : round(relativeErrorPercent),
    errorAvailable: hasExactValue,
    converged: true,
    reason,
  };
}

function buildGraphData(compiled, lowerBound, upperBound, pointCount = DEFAULT_GRAPH_POINT_COUNT) {
  const points = [];
  const step = (upperBound - lowerBound) / pointCount;

  for (let index = 0; index <= pointCount; index++) {
    const x = index === pointCount ? upperBound : lowerBound + step * index;

    points.push({
      x: round(x),
      y: round(evaluateAt(compiled, { x })),
    });
  }

  return points;
}

function buildExplanation(method, steps) {
  return {
    summary: `${method} approximated the definite integral over the requested interval.`,
    steps,
  };
}

function buildResult({ method, input, iterations, finalAnswer, explanation, graphData, warnings, start }) {
  return {
    method,
    status: 'converged',
    input,
    iterations,
    finalAnswer,
    explanation,
    graphData,
    warnings,
    executionTimeMs: Date.now() - start,
  };
}

function buildNewtonCotesRows(evaluate, lowerBound, h, subintervals, getCoefficient) {
  const iterations = [];
  let weightedSum = 0;

  for (let index = 0; index <= subintervals; index++) {
    const x = lowerBound + h * index;
    const fX = evaluate(x);
    const coefficient = getCoefficient(index, subintervals);
    const weightedValue = coefficient * fX;

    weightedSum += weightedValue;
    iterations.push({
      index,
      x: round(x),
      fX: round(fX),
      coefficient,
      weightedValue: round(weightedValue),
      formulaTemplate: 'weightedValue = coefficient * f(x)',
      substitution: `${coefficient} * f(${round(x)}) = ${coefficient} * ${round(fX)} = ${round(weightedValue)}`,
    });
  }

  return { iterations, weightedSum };
}

module.exports = {
  buildExplanation,
  buildFinalAnswer,
  buildGraphData,
  buildInput,
  buildNewtonCotesRows,
  buildResult,
  compileIntegrand,
  round,
};

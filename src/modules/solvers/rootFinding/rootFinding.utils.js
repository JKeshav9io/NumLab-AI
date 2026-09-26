'use strict';

const { evaluateAt } = require('../../../common/utils/mathParser');
const round = require('../../../common/utils/round');

const DEFAULT_GRAPH_POINT_COUNT = 80;

function buildFunctionGraphData(compiled, minX, maxX, pointCount = DEFAULT_GRAPH_POINT_COUNT) {
  const points = [];
  const start = minX === maxX ? minX - 1 : minX;
  const end = minX === maxX ? maxX + 1 : maxX;
  const step = (end - start) / pointCount;

  for (let i = 0; i <= pointCount; i++) {
    const x = i === pointCount ? end : start + step * i;
    points.push({
      x: round(x),
      y: round(evaluateAt(compiled, { x })),
    });
  }

  return points;
}

function buildExplanation(methodName, status, iterationsUsed, reason, steps) {
  return {
    summary: status === 'converged'
      ? `${methodName} converged because ${reason.toLowerCase()}.`
      : `${methodName} stopped with status "${status}" because ${reason.toLowerCase()}.`,
    steps: [
      ...steps,
      `Stop when the tolerance is reached, an exact root is found, the method fails, or the iteration limit is reached. Iterations used: ${iterationsUsed}.`,
    ],
  };
}

function buildResult({ method, status, input, iterations, finalAnswer, explanation, graphData, warnings, start }) {
  return {
    method,
    status,
    input,
    iterations,
    finalAnswer,
    explanation,
    graphData,
    warnings,
    executionTimeMs: Date.now() - start,
  };
}

module.exports = {
  buildExplanation,
  buildFunctionGraphData,
  buildResult,
  round,
};

'use strict';

const { AppError, errorCodes } = require('../../../common/errors');
const { compileExpression, evaluateAt } = require('../../../common/utils/mathParser');
const round = require('../../../common/utils/round');

const DEFAULT_GRAPH_POINT_COUNT = 80;
const POINT_MATCH_TOLERANCE = 1e-10;

function roundPoint(point) {
  return {
    x: round(point.x),
    y: round(point.y),
  };
}

function sortPoints(points) {
  return points
    .map((point) => ({ x: point.x, y: point.y }))
    .sort((a, b) => a.x - b.x);
}

function getEqualSpacing(points) {
  if (points.length < 2) {
    return 0;
  }

  return points[1].x - points[0].x;
}

function findPoint(points, x) {
  return points.find((point) => Math.abs(point.x - x) <= POINT_MATCH_TOLERANCE);
}

function requirePoint(points, x, label) {
  const point = findPoint(points, x);

  if (!point) {
    throw new AppError(
      `${label} point is required for this differentiation stencil`,
      400,
      errorCodes.SOLVER_PRECONDITION_FAILED,
      { x: round(x), label }
    );
  }

  return point;
}

function buildTabularInput(params, points) {
  return {
    points: points.map(roundPoint),
    targetX: round(params.targetX),
    exactDerivative: params.exactDerivative === undefined ? null : round(params.exactDerivative),
  };
}

function buildFunctionInput(params) {
  return {
    equation: params.equation,
    targetX: round(params.targetX),
    h: round(params.h),
    variant: params.variant,
    exactDerivative: params.exactDerivative === undefined ? null : round(params.exactDerivative),
  };
}

function buildFinalAnswer(derivative, exactDerivative, reason) {
  const hasExactDerivative = exactDerivative !== undefined;
  const absoluteError = hasExactDerivative ? Math.abs(exactDerivative - derivative) : null;
  const relativeErrorPercent = hasExactDerivative && exactDerivative !== 0
    ? (absoluteError / Math.abs(exactDerivative)) * 100
    : null;

  return {
    derivative: round(derivative),
    exactDerivative: hasExactDerivative ? round(exactDerivative) : null,
    absoluteError: hasExactDerivative ? round(absoluteError) : null,
    relativeErrorPercent: relativeErrorPercent === null ? null : round(relativeErrorPercent),
    errorAvailable: hasExactDerivative,
    converged: true,
    reason,
  };
}

function buildExplanation(method, steps) {
  return {
    summary: `${method} approximated the first derivative at the requested x value.`,
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

function buildTabularGraphData(points, targetX, derivative, stencilPoints) {
  return {
    originalPoints: points.map(roundPoint),
    stencilPoints: stencilPoints.map(roundPoint),
    derivativePoint: {
      x: round(targetX),
      derivative: round(derivative),
    },
  };
}

function buildFunctionGraphData(compiled, targetX, h, pointCount = DEFAULT_GRAPH_POINT_COUNT) {
  const span = Math.max(Math.abs(h) * 5, 1);
  const minX = targetX - span;
  const maxX = targetX + span;
  const step = (maxX - minX) / pointCount;
  const points = [];

  for (let index = 0; index <= pointCount; index++) {
    const x = index === pointCount ? maxX : minX + step * index;

    points.push({
      x: round(x),
      y: round(evaluateAt(compiled, { x })),
    });
  }

  return points;
}

function compileFunction(equation) {
  const compiled = compileExpression(equation);

  return {
    compiled,
    evaluate(x) {
      return evaluateAt(compiled, { x });
    },
  };
}

module.exports = {
  DEFAULT_GRAPH_POINT_COUNT,
  POINT_MATCH_TOLERANCE,
  buildExplanation,
  buildFinalAnswer,
  buildFunctionGraphData,
  buildFunctionInput,
  buildResult,
  buildTabularGraphData,
  buildTabularInput,
  compileFunction,
  findPoint,
  getEqualSpacing,
  requirePoint,
  round,
  roundPoint,
  sortPoints,
};

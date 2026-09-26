'use strict';

const { compileExpression, evaluateAt } = require('../../../common/utils/mathParser');
const round = require('../../../common/utils/round');

const STEP_MULTIPLE_TOLERANCE = 1e-10;

function buildInput(params, resolvedSteps) {
  return {
    equation: params.equation,
    x0: round(params.x0),
    y0: round(params.y0),
    h: round(params.h),
    xn: params.xn === undefined ? null : round(params.xn),
    steps: resolvedSteps,
  };
}

function resolveSteps(params) {
  if (params.steps !== undefined) {
    return params.steps;
  }

  return Math.round((params.xn - params.x0) / params.h);
}

function compileDerivative(equation) {
  const compiled = compileExpression(equation);

  return function derivative(x, y) {
    return evaluateAt(compiled, { x, y });
  };
}

function buildGraphData(points) {
  return points.map((point) => ({
    x: round(point.x),
    y: round(point.y),
  }));
}

function buildFinalAnswer(point, stepsUsed, reason = 'Completed requested steps') {
  return {
    x: round(point.x),
    y: round(point.y),
    stepsUsed,
    converged: true,
    reason,
  };
}

function buildExplanation(method, steps) {
  return {
    summary: `${method} computed the approximate solution for the requested ODE initial value problem.`,
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

function isWholeStepMultiple(x0, xn, h) {
  const rawSteps = (xn - x0) / h;
  return rawSteps > 0 && Math.abs(rawSteps - Math.round(rawSteps)) <= STEP_MULTIPLE_TOLERANCE;
}

module.exports = {
  STEP_MULTIPLE_TOLERANCE,
  buildExplanation,
  buildFinalAnswer,
  buildGraphData,
  buildInput,
  buildResult,
  compileDerivative,
  isWholeStepMultiple,
  resolveSteps,
  round,
};

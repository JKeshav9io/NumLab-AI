'use strict';

const { compileExpression, evaluateAt, numericalDerivative } = require('../../../common/utils/mathParser');
const {
  buildExplanation,
  buildFunctionGraphData,
  buildResult,
  round,
} = require('./rootFinding.utils');

const DERIVATIVE_NEAR_ZERO_THRESHOLD = 1e-12;

function solveNewtonRaphson(params) {
  const start = Date.now();
  const {
    equation,
    derivativeEquation,
    initialGuess,
    tolerance,
    maxIterations,
    includeExplanation,
    includeGraphData,
  } = params;

  const input = {
    equation,
    derivativeEquation: derivativeEquation || null,
    initialGuess,
    tolerance,
    maxIterations,
  };
  const f = compileExpression(equation);
  const derivative = derivativeEquation ? compileExpression(derivativeEquation) : null;
  const iterations = [];
  const warnings = [];

  if (!derivativeEquation) {
    warnings.push('No derivativeEquation provided; numerical derivative was used');
  }

  let x = initialGuess;

  for (let iteration = 1; iteration <= maxIterations; iteration++) {
    const fX = evaluateAt(f, { x });
    const derivativeValue = derivative
      ? evaluateAt(derivative, { x })
      : numericalDerivative(f, x);

    if (Math.abs(derivativeValue) < DERIVATIVE_NEAR_ZERO_THRESHOLD) {
      warnings.push('Derivative is near zero; Newton-Raphson cannot continue safely');
      return buildMethodResult({
        status: 'failed',
        input,
        iterations,
        finalAnswer: {
          root: round(x),
          functionValue: round(fX),
          iterationsUsed: iteration - 1,
          converged: false,
          reason: 'Derivative near zero',
        },
        includeExplanation,
        includeGraphData,
        f,
        graphMin: x - 2,
        graphMax: x + 2,
        warnings,
        start,
      });
    }

    const xNext = x - fX / derivativeValue;
    const error = Math.abs(xNext - x);
    const toleranceReached = error <= tolerance;
    const exactRoot = fX === 0;
    const decision = exactRoot
      ? 'Exact root found, stop'
      : toleranceReached
        ? `Error ${round(error)} <= tolerance ${tolerance}, stop`
        : `Error ${round(error)} > tolerance ${tolerance}, continue`;

    iterations.push({
      iteration,
      x: round(x),
      fX: round(fX),
      derivative: round(derivativeValue),
      xNext: round(xNext),
      formulaTemplate: "x_next = x - f(x) / f'(x)",
      substitution: `x_next = ${round(x)} - (${round(fX)} / ${round(derivativeValue)}) = ${round(xNext)}`,
      error: round(error),
      tolerance,
      decision,
    });

    if (exactRoot || toleranceReached) {
      const finalFunctionValue = exactRoot ? fX : evaluateAt(f, { x: xNext });
      const reason = exactRoot ? 'Exact root found' : 'Tolerance reached';
      return buildMethodResult({
        status: 'converged',
        input,
        iterations,
        finalAnswer: {
          root: round(exactRoot ? x : xNext),
          functionValue: round(finalFunctionValue),
          iterationsUsed: iteration,
          converged: true,
          reason,
        },
        includeExplanation,
        includeGraphData,
        f,
        graphMin: Math.min(initialGuess, xNext) - 2,
        graphMax: Math.max(initialGuess, xNext) + 2,
        warnings,
        start,
      });
    }

    x = xNext;
  }

  warnings.push(`Reached max iterations (${maxIterations}) before meeting tolerance`);
  return buildMethodResult({
    status: 'max_iterations_reached',
    input,
    iterations,
    finalAnswer: {
      root: round(x),
      functionValue: round(evaluateAt(f, { x })),
      iterationsUsed: maxIterations,
      converged: false,
      reason: 'Maximum iterations reached',
    },
    includeExplanation,
    includeGraphData,
    f,
    graphMin: Math.min(initialGuess, x) - 2,
    graphMax: Math.max(initialGuess, x) + 2,
    warnings,
    start,
  });
}

function buildMethodResult({
  status,
  input,
  iterations,
  finalAnswer,
  includeExplanation,
  includeGraphData,
  f,
  graphMin,
  graphMax,
  warnings,
  start,
}) {
  return buildResult({
    method: 'Newton-Raphson Method',
    status,
    input,
    iterations,
    finalAnswer,
    explanation: includeExplanation
      ? buildExplanation('Newton-Raphson Method', status, finalAnswer.iterationsUsed, finalAnswer.reason, [
        "Evaluate f(x) and f'(x) at the current guess.",
        "Apply x_next = x - f(x) / f'(x).",
        'Use the change between successive approximations as the error.',
      ])
      : null,
    graphData: includeGraphData ? buildFunctionGraphData(f, graphMin, graphMax) : [],
    warnings,
    start,
  });
}

module.exports = {
  solveNewtonRaphson,
  newtonRaphson: solveNewtonRaphson,
};

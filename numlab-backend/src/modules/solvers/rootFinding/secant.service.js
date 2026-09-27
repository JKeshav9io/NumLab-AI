'use strict';

const { compileExpression, evaluateAt } = require('../../../common/utils/mathParser');
const {
  buildExplanation,
  buildFunctionGraphData,
  buildResult,
  round,
} = require('./rootFinding.utils');

const DENOMINATOR_NEAR_ZERO_THRESHOLD = 1e-12;

function solveSecant(params) {
  const start = Date.now();
  const {
    equation,
    firstGuess,
    secondGuess,
    tolerance,
    maxIterations,
    includeExplanation,
    includeGraphData,
  } = params;

  const input = {
    equation,
    firstGuess,
    secondGuess,
    tolerance,
    maxIterations,
  };
  const f = compileExpression(equation);
  const iterations = [];
  const warnings = [];
  let x0 = firstGuess;
  let x1 = secondGuess;

  for (let iteration = 1; iteration <= maxIterations; iteration++) {
    const fX0 = evaluateAt(f, { x: x0 });
    const fX1 = evaluateAt(f, { x: x1 });
    const denominator = fX1 - fX0;

    if (Math.abs(denominator) < DENOMINATOR_NEAR_ZERO_THRESHOLD) {
      warnings.push('Secant denominator is near zero; method cannot continue safely');
      return buildMethodResult({
        status: 'failed',
        input,
        iterations,
        finalAnswer: {
          root: round(x1),
          functionValue: round(fX1),
          iterationsUsed: iteration - 1,
          converged: false,
          reason: 'Secant denominator near zero',
        },
        includeExplanation,
        includeGraphData,
        f,
        graphMin: Math.min(firstGuess, secondGuess) - 2,
        graphMax: Math.max(firstGuess, secondGuess) + 2,
        warnings,
        start,
      });
    }

    const xNext = x1 - fX1 * (x1 - x0) / denominator;
    const error = Math.abs(xNext - x1);
    const toleranceReached = error <= tolerance;
    const exactRoot = fX1 === 0;
    const decision = exactRoot
      ? 'Exact root found, stop'
      : toleranceReached
        ? `Error ${round(error)} <= tolerance ${tolerance}, stop`
        : `Error ${round(error)} > tolerance ${tolerance}, continue`;

    iterations.push({
      iteration,
      x0: round(x0),
      x1: round(x1),
      fX0: round(fX0),
      fX1: round(fX1),
      xNext: round(xNext),
      formulaTemplate: 'x_next = x1 - f(x1) * (x1 - x0) / (f(x1) - f(x0))',
      substitution: `x_next = ${round(x1)} - ${round(fX1)} * (${round(x1)} - ${round(x0)}) / (${round(fX1)} - ${round(fX0)}) = ${round(xNext)}`,
      error: round(error),
      tolerance,
      decision,
    });

    if (exactRoot || toleranceReached) {
      const finalFunctionValue = exactRoot ? fX1 : evaluateAt(f, { x: xNext });
      const reason = exactRoot ? 'Exact root found' : 'Tolerance reached';
      return buildMethodResult({
        status: 'converged',
        input,
        iterations,
        finalAnswer: {
          root: round(exactRoot ? x1 : xNext),
          functionValue: round(finalFunctionValue),
          iterationsUsed: iteration,
          converged: true,
          reason,
        },
        includeExplanation,
        includeGraphData,
        f,
        graphMin: Math.min(firstGuess, secondGuess, xNext) - 2,
        graphMax: Math.max(firstGuess, secondGuess, xNext) + 2,
        warnings,
        start,
      });
    }

    x0 = x1;
    x1 = xNext;
  }

  warnings.push(`Reached max iterations (${maxIterations}) before meeting tolerance`);
  return buildMethodResult({
    status: 'max_iterations_reached',
    input,
    iterations,
    finalAnswer: {
      root: round(x1),
      functionValue: round(evaluateAt(f, { x: x1 })),
      iterationsUsed: maxIterations,
      converged: false,
      reason: 'Maximum iterations reached',
    },
    includeExplanation,
    includeGraphData,
    f,
    graphMin: Math.min(firstGuess, secondGuess, x1) - 2,
    graphMax: Math.max(firstGuess, secondGuess, x1) + 2,
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
    method: 'Secant Method',
    status,
    input,
    iterations,
    finalAnswer,
    explanation: includeExplanation
      ? buildExplanation('Secant Method', status, finalAnswer.iterationsUsed, finalAnswer.reason, [
        'Start with two initial approximations.',
        'Approximate the tangent slope using the secant line through the two latest points.',
        'Use the change between successive approximations as the error.',
      ])
      : null,
    graphData: includeGraphData ? buildFunctionGraphData(f, graphMin, graphMax) : [],
    warnings,
    start,
  });
}

module.exports = {
  solveSecant,
  secant: solveSecant,
};

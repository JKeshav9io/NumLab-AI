'use strict';

const { compileExpression, evaluateAt } = require('../../../common/utils/mathParser');
const { AppError, errorCodes } = require('../../../common/errors');
const {
  buildExplanation,
  buildFunctionGraphData,
  buildResult,
  round,
} = require('./rootFinding.utils');

function solveRegulaFalsi(params) {
  const start = Date.now();
  const {
    equation,
    lowerBound,
    upperBound,
    tolerance,
    maxIterations,
    includeExplanation,
    includeGraphData,
  } = params;

  const input = {
    equation,
    lowerBound,
    upperBound,
    tolerance,
    maxIterations,
  };
  const f = compileExpression(equation);
  const initialFA = evaluateAt(f, { x: lowerBound });
  const initialFB = evaluateAt(f, { x: upperBound });

  if (initialFA === 0 || initialFB === 0) {
    const root = initialFA === 0 ? lowerBound : upperBound;
    const reason = initialFA === 0 ? 'Lower bound is an exact root' : 'Upper bound is an exact root';
    return buildMethodResult({
      status: 'converged',
      input,
      iterations: [],
      finalAnswer: {
        root: round(root),
        functionValue: 0,
        iterationsUsed: 0,
        converged: true,
        reason,
      },
      includeExplanation,
      includeGraphData,
      f,
      warnings: [],
      start,
    });
  }

  if (Math.sign(initialFA) === Math.sign(initialFB)) {
    throw new AppError(
      'Regula Falsi requires f(lowerBound) and f(upperBound) to have opposite signs',
      400,
      errorCodes.SOLVER_PRECONDITION_FAILED,
      {
        lowerBound,
        upperBound,
        fLowerBound: round(initialFA),
        fUpperBound: round(initialFB),
      }
    );
  }

  let a = lowerBound;
  let b = upperBound;
  let fA = initialFA;
  let fB = initialFB;
  let previousC = null;
  let lastC = null;
  let lastFC = null;
  const iterations = [];
  const warnings = [];

  for (let iteration = 1; iteration <= maxIterations; iteration++) {
    const c = (a * fB - b * fA) / (fB - fA);
    const fC = evaluateAt(f, { x: c });
    const error = previousC === null ? Math.abs(b - a) : Math.abs(c - previousC);
    const exactRoot = fC === 0;
    const toleranceReached = Math.abs(fC) <= tolerance || (previousC !== null && error <= tolerance);
    const nextInterval = Math.sign(fA) !== Math.sign(fC) ? '[a, c]' : '[c, b]';
    const decision = exactRoot
      ? 'Exact root found, stop'
      : toleranceReached
        ? `Tolerance reached with |f(c)| ${round(Math.abs(fC))} and error ${round(error)}, stop`
        : `Root lies in ${nextInterval}, continue`;

    iterations.push({
      iteration,
      a: round(a),
      b: round(b),
      c: round(c),
      fA: round(fA),
      fB: round(fB),
      fC: round(fC),
      formulaTemplate: 'c = (a*f(b) - b*f(a)) / (f(b) - f(a))',
      substitution: `c = (${round(a)}*${round(fB)} - ${round(b)}*${round(fA)}) / (${round(fB)} - ${round(fA)}) = ${round(c)}`,
      error: round(error),
      tolerance,
      decision,
    });

    lastC = c;
    lastFC = fC;

    if (exactRoot || toleranceReached) {
      const reason = exactRoot ? 'Exact root found' : 'Tolerance reached';
      return buildMethodResult({
        status: 'converged',
        input,
        iterations,
        finalAnswer: {
          root: round(c),
          functionValue: round(fC),
          iterationsUsed: iteration,
          converged: true,
          reason,
        },
        includeExplanation,
        includeGraphData,
        f,
        warnings,
        start,
      });
    }

    if (Math.sign(fA) !== Math.sign(fC)) {
      b = c;
      fB = fC;
    } else {
      a = c;
      fA = fC;
    }
    previousC = c;
  }

  warnings.push(`Reached max iterations (${maxIterations}) before meeting tolerance`);
  return buildMethodResult({
    status: 'max_iterations_reached',
    input,
    iterations,
    finalAnswer: {
      root: round(lastC),
      functionValue: round(lastFC),
      iterationsUsed: maxIterations,
      converged: false,
      reason: 'Maximum iterations reached',
    },
    includeExplanation,
    includeGraphData,
    f,
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
  warnings,
  start,
}) {
  return buildResult({
    method: 'Regula Falsi Method',
    status,
    input,
    iterations,
    finalAnswer,
    explanation: includeExplanation
      ? buildExplanation('Regula Falsi Method', status, finalAnswer.iterationsUsed, finalAnswer.reason, [
        'Check that the function changes sign across the starting interval.',
        'Compute the false-position point using the secant line between the interval endpoints.',
        'Keep the subinterval where the sign change remains.',
      ])
      : null,
    graphData: includeGraphData ? buildFunctionGraphData(f, input.lowerBound, input.upperBound) : [],
    warnings,
    start,
  });
}

module.exports = {
  solveRegulaFalsi,
  regulaFalsi: solveRegulaFalsi,
};

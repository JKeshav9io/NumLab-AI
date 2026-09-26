'use strict';

const { compileExpression, evaluateAt } = require('../../../common/utils/mathParser');
const { AppError, errorCodes } = require('../../../common/errors');

const DEFAULT_GRAPH_POINT_COUNT = 80;

function solveBisection(params) {
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

  const compiled = compileExpression(equation);
  const initialFA = evaluateAt(compiled, { x: lowerBound });
  const initialFB = evaluateAt(compiled, { x: upperBound });

  if (initialFA === 0) {
    return buildResult({
      status: 'converged',
      input,
      iterations: [],
      finalAnswer: {
        root: round(lowerBound),
        functionValue: 0,
        iterationsUsed: 0,
        converged: true,
        reason: 'Lower bound is an exact root',
      },
      explanation: includeExplanation ? buildExplanation('converged', 0, 'Lower bound is an exact root') : null,
      graphData: includeGraphData ? buildGraphData(compiled, lowerBound, upperBound) : [],
      warnings: [],
      start,
    });
  }

  if (initialFB === 0) {
    return buildResult({
      status: 'converged',
      input,
      iterations: [],
      finalAnswer: {
        root: round(upperBound),
        functionValue: 0,
        iterationsUsed: 0,
        converged: true,
        reason: 'Upper bound is an exact root',
      },
      explanation: includeExplanation ? buildExplanation('converged', 0, 'Upper bound is an exact root') : null,
      graphData: includeGraphData ? buildGraphData(compiled, lowerBound, upperBound) : [],
      warnings: [],
      start,
    });
  }

  if (Math.sign(initialFA) === Math.sign(initialFB)) {
    throw new AppError(
      'Bisection requires f(lowerBound) and f(upperBound) to have opposite signs',
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
  let lastC = null;
  let lastFC = null;
  const iterations = [];
  const warnings = [];

  for (let iteration = 1; iteration <= maxIterations; iteration++) {
    const c = (a + b) / 2;
    const fC = evaluateAt(compiled, { x: c });
    const error = Math.abs(b - a) / 2;
    const exactRoot = fC === 0;
    const toleranceReached = error <= tolerance;
    const nextInterval = Math.sign(fA) !== Math.sign(fC) ? '[a, c]' : '[c, b]';
    const decision = exactRoot
      ? 'Exact root found at midpoint, stop'
      : toleranceReached
        ? `Error ${round(error)} <= tolerance ${tolerance}, stop`
        : `Root lies in ${nextInterval}, continue`;

    iterations.push({
      iteration,
      a: round(a),
      b: round(b),
      c: round(c),
      fA: round(fA),
      fB: round(fB),
      fC: round(fC),
      formulaTemplate: 'c = (a + b) / 2',
      substitution: `c = (${round(a)} + ${round(b)}) / 2 = ${round(c)}`,
      error: round(error),
      tolerance,
      decision,
    });

    lastC = c;
    lastFC = fC;

    if (exactRoot || toleranceReached) {
      const reason = exactRoot ? 'Exact root found' : 'Tolerance reached';
      return buildResult({
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
        explanation: includeExplanation ? buildExplanation('converged', iteration, reason) : null,
        graphData: includeGraphData ? buildGraphData(compiled, lowerBound, upperBound) : [],
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
  }

  warnings.push(`Reached max iterations (${maxIterations}) before meeting tolerance`);

  return buildResult({
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
    explanation: includeExplanation
      ? buildExplanation('max_iterations_reached', maxIterations, 'Maximum iterations reached')
      : null,
    graphData: includeGraphData ? buildGraphData(compiled, lowerBound, upperBound) : [],
    warnings,
    start,
  });
}

function buildResult({ status, input, iterations, finalAnswer, explanation, graphData, warnings, start }) {
  return {
    method: 'Bisection Method',
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

function buildExplanation(status, iterationsUsed, reason) {
  return {
    summary: status === 'converged'
      ? `The bisection method converged because the interval was repeatedly halved until ${reason.toLowerCase()}.`
      : 'The bisection method reduced the interval but did not meet the stopping criteria in time.',
    steps: [
      'Check that the function changes sign across the starting interval.',
      'Compute the midpoint c = (a + b) / 2.',
      'Evaluate f(c) and keep the subinterval where the sign change remains.',
      `Stop when the tolerance is reached, an exact midpoint root is found, or the iteration limit is reached. Iterations used: ${iterationsUsed}.`,
    ],
  };
}

function buildGraphData(compiled, lowerBound, upperBound) {
  const points = [];
  const step = (upperBound - lowerBound) / DEFAULT_GRAPH_POINT_COUNT;

  for (let i = 0; i <= DEFAULT_GRAPH_POINT_COUNT; i++) {
    const x = i === DEFAULT_GRAPH_POINT_COUNT ? upperBound : lowerBound + step * i;
    points.push({
      x: round(x),
      y: round(evaluateAt(compiled, { x })),
    });
  }

  return points;
}

function round(value, decimals = 10) {
  const rounded = Number.parseFloat(value.toFixed(decimals));
  return Object.is(rounded, -0) ? 0 : rounded;
}

module.exports = {
  solveBisection,
};

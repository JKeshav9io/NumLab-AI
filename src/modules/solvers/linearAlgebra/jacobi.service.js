'use strict';

const { AppError, errorCodes } = require('../../../common/errors');
const {
  buildExplanation,
  buildResult,
  hasZeroDiagonal,
  isDiagonallyDominant,
  maxAbsDifference,
  residualVector,
  round,
  roundMatrix,
  roundVector,
} = require('./linearAlgebra.utils');

function solveJacobi(params) {
  const start = Date.now();
  const {
    matrix,
    constants,
    initialGuess,
    tolerance,
    maxIterations,
    includeExplanation,
  } = params;
  const n = matrix.length;
  const input = {
    matrix: roundMatrix(matrix),
    constants: roundVector(constants),
    initialGuess: roundVector(initialGuess || Array(n).fill(0)),
    tolerance,
    maxIterations,
  };
  const warnings = [];
  const iterations = [];

  if (hasZeroDiagonal(matrix)) {
    throw new AppError(
      'Jacobi requires non-zero diagonal entries',
      400,
      errorCodes.SOLVER_PRECONDITION_FAILED
    );
  }

  if (!isDiagonallyDominant(matrix)) {
    warnings.push('Matrix is not diagonally dominant; convergence is not guaranteed');
  }

  let current = initialGuess ? initialGuess.slice() : Array(n).fill(0);

  for (let iteration = 1; iteration <= maxIterations; iteration++) {
    const next = Array(n).fill(0);
    const formulas = [];

    for (let row = 0; row < n; row++) {
      let sum = constants[row];
      const terms = [];

      for (let col = 0; col < n; col++) {
        if (col !== row) {
          sum -= matrix[row][col] * current[col];
          terms.push(`${round(matrix[row][col])}*${round(current[col])}`);
        }
      }

      next[row] = sum / matrix[row][row];
      formulas.push(`x${row + 1} = (${round(constants[row])} - ${terms.join(' - ') || '0'}) / ${round(matrix[row][row])}`);
    }

    const error = maxAbsDifference(next, current);
    const toleranceReached = error <= tolerance;

    iterations.push({
      iteration,
      previous: roundVector(current),
      current: roundVector(next),
      formulas,
      error: round(error),
      tolerance,
      decision: toleranceReached
        ? `Error ${round(error)} <= tolerance ${tolerance}, stop`
        : `Error ${round(error)} > tolerance ${tolerance}, continue`,
    });

    if (toleranceReached) {
      return buildIterativeResult({
        method: 'Jacobi Method',
        status: 'converged',
        input,
        iterations,
        solution: next,
        matrix,
        constants,
        includeExplanation,
        warnings,
        reason: 'Tolerance reached',
        start,
      });
    }

    current = next;
  }

  warnings.push(`Reached max iterations (${maxIterations}) before meeting tolerance`);

  return buildIterativeResult({
    method: 'Jacobi Method',
    status: 'max_iterations_reached',
    input,
    iterations,
    solution: current,
    matrix,
    constants,
    includeExplanation,
    warnings,
    reason: 'Maximum iterations reached',
    start,
  });
}

function buildIterativeResult({
  method,
  status,
  input,
  iterations,
  solution,
  matrix,
  constants,
  includeExplanation,
  warnings,
  reason,
  start,
}) {
  return buildResult({
    method,
    status,
    input,
    iterations,
    finalAnswer: {
      solution: roundVector(solution),
      residuals: residualVector(matrix, constants, solution),
      variables: buildVariableMap(solution),
      iterationsUsed: iterations.length,
      converged: status === 'converged',
      reason,
    },
    explanation: includeExplanation
      ? buildExplanation(method, status, iterations.length, reason, [
        'Rearrange each equation to solve for its diagonal variable.',
        'Compute every variable using values from the previous iteration only.',
        'Use the largest absolute change between successive vectors as the error.',
      ])
      : null,
    warnings,
    start,
  });
}

function buildVariableMap(solution) {
  return solution.reduce((variables, value, index) => {
    variables[`x${index + 1}`] = round(value);
    return variables;
  }, {});
}

module.exports = {
  solveJacobi,
  jacobi: solveJacobi,
};

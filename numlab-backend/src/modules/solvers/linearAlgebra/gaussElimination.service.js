'use strict';

const { AppError, errorCodes } = require('../../../common/errors');
const {
  buildExplanation,
  buildResult,
  cloneMatrix,
  cloneVector,
  residualVector,
  round,
  roundMatrix,
  roundVector,
} = require('./linearAlgebra.utils');

const PIVOT_NEAR_ZERO_THRESHOLD = 1e-12;

function solveGaussElimination(params) {
  const start = Date.now();
  const {
    matrix,
    constants,
    includeExplanation,
  } = params;
  const input = {
    matrix: roundMatrix(matrix),
    constants: roundVector(constants),
  };
  const a = cloneMatrix(matrix);
  const b = cloneVector(constants);
  const n = a.length;
  const iterations = [];
  const warnings = [];

  for (let pivotIndex = 0; pivotIndex < n - 1; pivotIndex++) {
    const maxRow = findPivotRow(a, pivotIndex);

    if (Math.abs(a[maxRow][pivotIndex]) < PIVOT_NEAR_ZERO_THRESHOLD) {
      throw new AppError(
        'Matrix is singular or nearly singular',
        400,
        errorCodes.SOLVER_PRECONDITION_FAILED,
        { pivotIndex }
      );
    }

    if (maxRow !== pivotIndex) {
      [a[pivotIndex], a[maxRow]] = [a[maxRow], a[pivotIndex]];
      [b[pivotIndex], b[maxRow]] = [b[maxRow], b[pivotIndex]];

      iterations.push({
        step: iterations.length + 1,
        phase: 'pivot',
        pivotRow: pivotIndex + 1,
        swappedWithRow: maxRow + 1,
        matrix: roundMatrix(a),
        constants: roundVector(b),
        description: `Swapped row ${pivotIndex + 1} with row ${maxRow + 1} for numerical stability`,
      });
    }

    for (let row = pivotIndex + 1; row < n; row++) {
      const factor = a[row][pivotIndex] / a[pivotIndex][pivotIndex];

      for (let col = pivotIndex; col < n; col++) {
        a[row][col] -= factor * a[pivotIndex][col];
      }
      b[row] -= factor * b[pivotIndex];

      iterations.push({
        step: iterations.length + 1,
        phase: 'elimination',
        pivotRow: pivotIndex + 1,
        targetRow: row + 1,
        factor: round(factor),
        formulaTemplate: 'R_target = R_target - factor * R_pivot',
        substitution: `R${row + 1} = R${row + 1} - (${round(factor)}) * R${pivotIndex + 1}`,
        matrix: roundMatrix(a),
        constants: roundVector(b),
      });
    }
  }

  if (Math.abs(a[n - 1][n - 1]) < PIVOT_NEAR_ZERO_THRESHOLD) {
    throw new AppError(
      'Matrix is singular or nearly singular',
      400,
      errorCodes.SOLVER_PRECONDITION_FAILED,
      { pivotIndex: n - 1 }
    );
  }

  const solution = backSubstitute(a, b);

  return buildResult({
    method: 'Gauss Elimination',
    status: 'converged',
    input,
    iterations,
    finalAnswer: {
      solution: roundVector(solution),
      residuals: residualVector(matrix, constants, solution),
      variables: buildVariableMap(solution),
      converged: true,
      reason: 'Back substitution completed',
    },
    explanation: includeExplanation
      ? buildExplanation('Gauss Elimination', 'converged', iterations.length, 'Back substitution completed', [
        'Use partial pivoting to choose a stable pivot row.',
        'Eliminate entries below each pivot to form an upper triangular system.',
        'Apply back substitution to compute each variable from bottom to top.',
      ])
      : null,
    warnings,
    start,
  });
}

function findPivotRow(matrix, pivotIndex) {
  let maxRow = pivotIndex;

  for (let row = pivotIndex + 1; row < matrix.length; row++) {
    if (Math.abs(matrix[row][pivotIndex]) > Math.abs(matrix[maxRow][pivotIndex])) {
      maxRow = row;
    }
  }

  return maxRow;
}

function backSubstitute(matrix, constants) {
  const n = matrix.length;
  const solution = Array(n).fill(0);

  for (let row = n - 1; row >= 0; row--) {
    let sum = constants[row];

    for (let col = row + 1; col < n; col++) {
      sum -= matrix[row][col] * solution[col];
    }

    solution[row] = sum / matrix[row][row];
  }

  return solution;
}

function buildVariableMap(solution) {
  return solution.reduce((variables, value, index) => {
    variables[`x${index + 1}`] = round(value);
    return variables;
  }, {});
}

module.exports = {
  solveGaussElimination,
  gaussElimination: solveGaussElimination,
};

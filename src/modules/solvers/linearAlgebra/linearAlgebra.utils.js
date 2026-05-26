'use strict';

function cloneMatrix(matrix) {
  return matrix.map((row) => row.slice());
}

function cloneVector(vector) {
  return vector.slice();
}

function round(value, decimals = 10) {
  const rounded = Number.parseFloat(value.toFixed(decimals));
  return Object.is(rounded, -0) ? 0 : rounded;
}

function roundVector(vector) {
  return vector.map((value) => round(value));
}

function roundMatrix(matrix) {
  return matrix.map((row) => roundVector(row));
}

function maxAbsDifference(a, b) {
  return Math.max(...a.map((value, index) => Math.abs(value - b[index])));
}

function residualVector(matrix, constants, solution) {
  return matrix.map((row, rowIndex) => {
    const computed = row.reduce((sum, coefficient, colIndex) => (
      sum + coefficient * solution[colIndex]
    ), 0);

    return round(computed - constants[rowIndex]);
  });
}

function isDiagonallyDominant(matrix) {
  return matrix.every((row, rowIndex) => {
    const diagonal = Math.abs(row[rowIndex]);
    const offDiagonalSum = row.reduce((sum, value, colIndex) => (
      colIndex === rowIndex ? sum : sum + Math.abs(value)
    ), 0);

    return diagonal >= offDiagonalSum;
  });
}

function hasZeroDiagonal(matrix, threshold = 1e-12) {
  return matrix.some((row, rowIndex) => Math.abs(row[rowIndex]) < threshold);
}

function buildExplanation(method, status, iterationsUsed, reason, steps) {
  return {
    summary: status === 'converged'
      ? `${method} solved the linear system because ${reason.toLowerCase()}.`
      : `${method} stopped with status "${status}" because ${reason.toLowerCase()}.`,
    steps: [
      ...steps,
      `Stop when the solution is found, the tolerance is reached, the matrix is singular, or the iteration limit is reached. Iterations used: ${iterationsUsed}.`,
    ],
  };
}

function buildResult({ method, status, input, iterations, finalAnswer, explanation, warnings, start }) {
  return {
    method,
    status,
    input,
    iterations,
    finalAnswer,
    explanation,
    graphData: [],
    warnings,
    executionTimeMs: Date.now() - start,
  };
}

module.exports = {
  buildExplanation,
  buildResult,
  cloneMatrix,
  cloneVector,
  hasZeroDiagonal,
  isDiagonallyDominant,
  maxAbsDifference,
  residualVector,
  round,
  roundMatrix,
  roundVector,
};

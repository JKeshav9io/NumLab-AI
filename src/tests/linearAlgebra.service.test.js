'use strict';

const { solveGaussElimination } = require('../modules/solvers/linearAlgebra/gaussElimination.service');
const { solveJacobi } = require('../modules/solvers/linearAlgebra/jacobi.service');
const { solveGaussSeidel } = require('../modules/solvers/linearAlgebra/gaussSeidel.service');
const { AppError, errorCodes } = require('../common/errors');

const matrix = [
  [10, -1, 2],
  [-1, 11, -1],
  [2, -1, 10],
];
const constants = [6, 25, -11];
const expectedSolution = [1.0432692308, 2.2692307692, -1.0817307692];

describe('Linear algebra services', () => {
  test('Gauss Elimination solves a 3x3 system', () => {
    const result = solveGaussElimination({
      matrix,
      constants,
      includeExplanation: true,
    });

    expect(result.method).toBe('Gauss Elimination');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.solution[0]).toBeCloseTo(expectedSolution[0], 6);
    expect(result.finalAnswer.solution[1]).toBeCloseTo(expectedSolution[1], 6);
    expect(result.finalAnswer.solution[2]).toBeCloseTo(expectedSolution[2], 6);
    expect(result.iterations.length).toBeGreaterThan(0);
    expect(result.finalAnswer.variables).toHaveProperty('x1');
  });

  test('Gauss Elimination throws for a singular matrix', () => {
    expect(() => solveGaussElimination({
      matrix: [
        [1, 2],
        [2, 4],
      ],
      constants: [3, 6],
      includeExplanation: true,
    })).toThrow(AppError);

    try {
      solveGaussElimination({
        matrix: [
          [1, 2],
          [2, 4],
        ],
        constants: [3, 6],
        includeExplanation: true,
      });
    } catch (err) {
      expect(err.code).toBe(errorCodes.SOLVER_PRECONDITION_FAILED);
    }
  });

  test('Jacobi converges for a diagonally dominant 3x3 system', () => {
    const result = solveJacobi({
      matrix,
      constants,
      initialGuess: [0, 0, 0],
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
    });

    expect(result.method).toBe('Jacobi Method');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.solution[0]).toBeCloseTo(expectedSolution[0], 3);
    expect(result.finalAnswer.solution[1]).toBeCloseTo(expectedSolution[1], 3);
    expect(result.finalAnswer.solution[2]).toBeCloseTo(expectedSolution[2], 3);
    expect(result.iterations[0]).toHaveProperty('formulas');
  });

  test('Gauss-Seidel converges for a diagonally dominant 3x3 system', () => {
    const result = solveGaussSeidel({
      matrix,
      constants,
      initialGuess: [0, 0, 0],
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
    });

    expect(result.method).toBe('Gauss-Seidel Method');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.solution[0]).toBeCloseTo(expectedSolution[0], 3);
    expect(result.finalAnswer.solution[1]).toBeCloseTo(expectedSolution[1], 3);
    expect(result.finalAnswer.solution[2]).toBeCloseTo(expectedSolution[2], 3);
    expect(result.iterations[0]).toHaveProperty('current');
  });

  test('Jacobi warns when matrix is not diagonally dominant', () => {
    const result = solveJacobi({
      matrix: [
        [2, 3],
        [4, 1],
      ],
      constants: [5, 6],
      initialGuess: [0, 0],
      tolerance: 0.0001,
      maxIterations: 2,
      includeExplanation: false,
    });

    expect(result.warnings).toContain('Matrix is not diagonally dominant; convergence is not guaranteed');
  });
});

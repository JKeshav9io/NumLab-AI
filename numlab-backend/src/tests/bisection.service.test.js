'use strict';

const { solveBisection } = require('../modules/solvers/rootFinding/bisection.service');
const { AppError, errorCodes } = require('../common/errors');

describe('Bisection service', () => {
  test('converges for x^3 - x - 2 on [1, 2]', () => {
    const result = solveBisection({
      equation: 'x^3 - x - 2',
      lowerBound: 1,
      upperBound: 2,
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
      includeGraphData: true,
    });

    expect(result.method).toBe('Bisection Method');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.converged).toBe(true);
    expect(result.finalAnswer.root).toBeCloseTo(1.5214, 3);
    expect(result.iterations.length).toBeGreaterThan(0);
    expect(result.graphData.length).toBeGreaterThan(0);
    expect(result.explanation.summary).toContain('bisection method converged');
  });

  test('throws precondition error when interval does not bracket a root', () => {
    try {
      solveBisection({
        equation: 'x^2 + 1',
        lowerBound: -1,
        upperBound: 1,
        tolerance: 0.0001,
        maxIterations: 100,
        includeExplanation: true,
        includeGraphData: true,
      });
      throw new Error('Expected solveBisection to throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect(err.code).toBe(errorCodes.SOLVER_PRECONDITION_FAILED);
      expect(err.details).toMatchObject({
        lowerBound: -1,
        upperBound: 1,
      });
    }
  });

  test('returns max_iterations_reached when tolerance is not reached in time', () => {
    const result = solveBisection({
      equation: 'x^3 - x - 2',
      lowerBound: 1,
      upperBound: 2,
      tolerance: 1e-12,
      maxIterations: 2,
      includeExplanation: true,
      includeGraphData: false,
    });

    expect(result.status).toBe('max_iterations_reached');
    expect(result.finalAnswer.converged).toBe(false);
    expect(result.finalAnswer.iterationsUsed).toBe(2);
    expect(result.warnings).toHaveLength(1);
    expect(result.graphData).toEqual([]);
  });

  test('iteration rows include required student-facing fields', () => {
    const result = solveBisection({
      equation: 'x^3 - x - 2',
      lowerBound: 1,
      upperBound: 2,
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
      includeGraphData: false,
    });

    const iteration = result.iterations[0];
    expect(iteration).toHaveProperty('iteration');
    expect(iteration).toHaveProperty('a');
    expect(iteration).toHaveProperty('b');
    expect(iteration).toHaveProperty('c');
    expect(iteration).toHaveProperty('fA');
    expect(iteration).toHaveProperty('fB');
    expect(iteration).toHaveProperty('fC');
    expect(iteration).toHaveProperty('formulaTemplate');
    expect(iteration).toHaveProperty('substitution');
    expect(iteration).toHaveProperty('error');
    expect(iteration).toHaveProperty('decision');
  });

  test('regression: correctly detects same-sign bounds with Math.sign even when product underflows', () => {
    expect(() => solveBisection({
      equation: '1e-200 * x^2 + 1e-200',
      lowerBound: 1,
      upperBound: 2,
      tolerance: 0.0001,
      maxIterations: 100,
    })).toThrow(AppError);

    try {
      solveBisection({
        equation: '1e-200 * x^2 + 1e-200',
        lowerBound: 1,
        upperBound: 2,
        tolerance: 0.0001,
        maxIterations: 100,
      });
    } catch (err) {
      expect(err.code).toBe(errorCodes.SOLVER_PRECONDITION_FAILED);
    }
  });
});


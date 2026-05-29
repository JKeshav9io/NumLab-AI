'use strict';

const { solveTrapezoidal } = require('../modules/solvers/integration/trapezoidal.service');
const { solveSimpsonOneThird } = require('../modules/solvers/integration/simpsonOneThird.service');
const { solveSimpsonThreeEighth } = require('../modules/solvers/integration/simpsonThreeEighth.service');
const { solveGaussLegendre } = require('../modules/solvers/integration/gaussLegendre.service');

const baseParams = {
  equation: 'x^2',
  lowerBound: 0,
  upperBound: 1,
  exactValue: 1 / 3,
  includeExplanation: true,
  includeGraphData: true,
};

describe('Integration services', () => {
  test('Trapezoidal Rule approximates an integral and computes true error', () => {
    const result = solveTrapezoidal({
      ...baseParams,
      subintervals: 4,
    });

    expect(result.method).toBe('Trapezoidal Rule');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.integral).toBeCloseTo(0.34375, 10);
    expect(result.finalAnswer.absoluteError).toBeCloseTo(0.0104166667, 10);
    expect(result.finalAnswer.relativeErrorPercent).toBeCloseTo(3.125, 10);
    expect(result.finalAnswer.errorAvailable).toBe(true);
    expect(result.iterations).toHaveLength(5);
    expect(result.iterations[0]).toHaveProperty('coefficient');
    expect(result.iterations[0]).toHaveProperty('weightedValue');
    expect(result.graphData).toHaveLength(81);
  });

  test("Simpson's 1/3 Rule integrates a quadratic exactly with even subintervals", () => {
    const result = solveSimpsonOneThird({
      ...baseParams,
      subintervals: 4,
    });

    expect(result.method).toBe("Simpson's 1/3 Rule");
    expect(result.finalAnswer.integral).toBeCloseTo(1 / 3, 10);
    expect(result.finalAnswer.absoluteError).toBeCloseTo(0, 10);
    expect(result.iterations.map((row) => row.coefficient)).toEqual([1, 4, 2, 4, 1]);
  });

  test("Simpson's 3/8 Rule integrates a quadratic exactly with subintervals divisible by 3", () => {
    const result = solveSimpsonThreeEighth({
      ...baseParams,
      subintervals: 3,
    });

    expect(result.method).toBe("Simpson's 3/8 Rule");
    expect(result.finalAnswer.integral).toBeCloseTo(1 / 3, 10);
    expect(result.finalAnswer.absoluteError).toBeCloseTo(0, 10);
    expect(result.iterations.map((row) => row.coefficient)).toEqual([1, 3, 3, 1]);
  });

  test.each([2, 3, 5])('Gauss-Legendre Quadrature integrates a quadratic with %i points', (points) => {
    const result = solveGaussLegendre({
      ...baseParams,
      points,
    });

    expect(result.method).toBe('Gauss-Legendre Quadrature');
    expect(result.finalAnswer.integral).toBeCloseTo(1 / 3, 10);
    expect(result.finalAnswer.absoluteError).toBeCloseTo(0, 10);
    expect(result.iterations).toHaveLength(points);
    expect(result.iterations[0]).toHaveProperty('node');
    expect(result.iterations[0]).toHaveProperty('mappedX');
  });

  test('Integration services support disabled explanation and graph output', () => {
    const result = solveGaussLegendre({
      equation: 'x^2',
      lowerBound: 0,
      upperBound: 1,
      points: 3,
      includeExplanation: false,
      includeGraphData: false,
    });

    expect(result.explanation).toBeNull();
    expect(result.graphData).toEqual([]);
    expect(result.finalAnswer.exactValue).toBeNull();
    expect(result.finalAnswer.absoluteError).toBeNull();
    expect(result.finalAnswer.relativeErrorPercent).toBeNull();
    expect(result.finalAnswer.errorAvailable).toBe(false);
  });

  test('Relative error is null when exactValue is zero', () => {
    const result = solveTrapezoidal({
      equation: 'x',
      lowerBound: -1,
      upperBound: 1,
      subintervals: 2,
      exactValue: 0,
      includeExplanation: false,
      includeGraphData: false,
    });

    expect(result.finalAnswer.absoluteError).toBe(0);
    expect(result.finalAnswer.relativeErrorPercent).toBeNull();
    expect(result.finalAnswer.errorAvailable).toBe(true);
  });
});

'use strict';

const { solveForwardDifference } = require('../modules/solvers/differentiation/forwardDifference.service');
const { solveBackwardDifference } = require('../modules/solvers/differentiation/backwardDifference.service');
const { solveCentralDifference } = require('../modules/solvers/differentiation/centralDifference.service');
const { solveLagrangeDifferentiation } = require('../modules/solvers/differentiation/lagrangeDifferentiation.service');
const { solveFunctionFiniteDifference } = require('../modules/solvers/differentiation/functionFiniteDifference.service');

const tabularParams = {
  points: [
    { x: 0, y: 1 },
    { x: 1, y: 4 },
    { x: 2, y: 9 },
    { x: 3, y: 16 },
  ],
  targetX: 1,
  exactDerivative: 4,
  includeExplanation: true,
  includeGraphData: true,
};

describe('Differentiation services', () => {
  test('Forward Difference computes a first derivative estimate with true error', () => {
    const result = solveForwardDifference(tabularParams);

    expect(result.method).toBe('Forward Difference');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.derivative).toBeCloseTo(5, 10);
    expect(result.finalAnswer.absoluteError).toBeCloseTo(1, 10);
    expect(result.finalAnswer.relativeErrorPercent).toBeCloseTo(25, 10);
    expect(result.finalAnswer.errorAvailable).toBe(true);
    expect(result.iterations[0]).toHaveProperty('fXPlusH');
    expect(result.graphData.stencilPoints).toHaveLength(2);
  });

  test('Backward Difference computes a first derivative estimate', () => {
    const result = solveBackwardDifference(tabularParams);

    expect(result.method).toBe('Backward Difference');
    expect(result.finalAnswer.derivative).toBeCloseTo(3, 10);
    expect(result.iterations[0]).toHaveProperty('fXMinusH');
    expect(result.iterations[0]).toHaveProperty('fX');
  });

  test('Central Difference uses neighboring points around targetX', () => {
    const result = solveCentralDifference(tabularParams);

    expect(result.method).toBe('Central Difference');
    expect(result.finalAnswer.derivative).toBeCloseTo(4, 10);
    expect(result.finalAnswer.absoluteError).toBeCloseTo(0, 10);
    expect(result.iterations[0]).toHaveProperty('fXMinusH');
    expect(result.iterations[0]).toHaveProperty('fXPlusH');
  });

  test('Lagrange Differentiation supports non-uniform points', () => {
    const result = solveLagrangeDifferentiation({
      points: [
        { x: 0, y: 1 },
        { x: 1, y: 4 },
        { x: 3, y: 16 },
      ],
      targetX: 1,
      exactDerivative: 4,
      includeExplanation: true,
      includeGraphData: true,
    });

    expect(result.method).toBe('Lagrange Differentiation');
    expect(result.finalAnswer.derivative).toBeCloseTo(4, 10);
    expect(result.iterations).toHaveLength(3);
    expect(result.iterations[0]).toHaveProperty('basisDerivative');
  });

  test.each([
    ['forward', 4.001],
    ['backward', 3.999],
    ['central', 4],
  ])('Function-based Finite Difference supports %s variant', (variant, derivative) => {
    const result = solveFunctionFiniteDifference({
      equation: 'x^2 + 2*x + 1',
      targetX: 1,
      h: 0.001,
      variant,
      exactDerivative: 4,
      includeExplanation: true,
      includeGraphData: true,
    });

    expect(result.method).toBe('Function-based Finite Difference');
    expect(result.input.variant).toBe(variant);
    expect(result.finalAnswer.derivative).toBeCloseTo(derivative, 6);
    expect(result.graphData).toHaveLength(81);
  });

  test('Differentiation services support disabled explanation and graph output', () => {
    const result = solveFunctionFiniteDifference({
      equation: 'x^2 + 2*x + 1',
      targetX: 1,
      h: 0.001,
      variant: 'central',
      includeExplanation: false,
      includeGraphData: false,
    });

    expect(result.explanation).toBeNull();
    expect(result.graphData).toEqual([]);
    expect(result.finalAnswer.exactDerivative).toBeNull();
    expect(result.finalAnswer.absoluteError).toBeNull();
    expect(result.finalAnswer.relativeErrorPercent).toBeNull();
    expect(result.finalAnswer.errorAvailable).toBe(false);
  });

  test('Relative error is null when exactDerivative is zero', () => {
    const result = solveCentralDifference({
      points: [
        { x: -1, y: 1 },
        { x: 0, y: 0 },
        { x: 1, y: 1 },
      ],
      targetX: 0,
      exactDerivative: 0,
      includeExplanation: false,
      includeGraphData: false,
    });

    expect(result.finalAnswer.derivative).toBe(0);
    expect(result.finalAnswer.absoluteError).toBe(0);
    expect(result.finalAnswer.relativeErrorPercent).toBeNull();
    expect(result.finalAnswer.errorAvailable).toBe(true);
  });
});

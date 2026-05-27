'use strict';

const { solveEuler } = require('../modules/solvers/ode/euler.service');
const { solveHeun } = require('../modules/solvers/ode/heun.service');
const { solveRK4 } = require('../modules/solvers/ode/rk4.service');
const { solveMilne } = require('../modules/solvers/ode/milne.service');

const params = {
  equation: 'x + y',
  x0: 0,
  y0: 1,
  h: 0.1,
  steps: 10,
  includeExplanation: true,
  includeGraphData: true,
};

describe('ODE services', () => {
  test('Euler Method returns a full iteration table and graph data', () => {
    const result = solveEuler(params);

    expect(result.method).toBe('Euler Method');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.y).toBeCloseTo(3.1874849202, 8);
    expect(result.iterations).toHaveLength(10);
    expect(result.iterations[0]).toHaveProperty('fXY');
    expect(result.iterations[0]).toHaveProperty('nextY');
    expect(result.graphData).toHaveLength(11);
  });

  test('Heun Method returns predictor and corrected values', () => {
    const result = solveHeun({
      ...params,
      includeGraphData: false,
    });

    expect(result.method).toBe('Heun / Improved Euler Method');
    expect(result.finalAnswer.y).toBeCloseTo(3.4281616932, 8);
    expect(result.iterations[0]).toHaveProperty('predictor');
    expect(result.iterations[0]).toHaveProperty('k1');
    expect(result.iterations[0]).toHaveProperty('k2');
    expect(result.iterations[0]).toHaveProperty('correctedY');
    expect(result.graphData).toEqual([]);
  });

  test('RK4 Method returns four slopes per step', () => {
    const result = solveRK4(params);

    expect(result.method).toBe('RK4 Method');
    expect(result.finalAnswer.y).toBeCloseTo(3.4365594883, 8);
    expect(result.iterations[0]).toHaveProperty('k1');
    expect(result.iterations[0]).toHaveProperty('k2');
    expect(result.iterations[0]).toHaveProperty('k3');
    expect(result.iterations[0]).toHaveProperty('k4');
    expect(result.iterations[0]).toHaveProperty('nextY');
  });

  test('Milne Predictor-Corrector uses RK4 starter rows and corrected values', () => {
    const result = solveMilne(params);

    expect(result.method).toBe('Milne Predictor-Corrector Method');
    expect(result.finalAnswer.y).toBeCloseTo(3.4365630324, 8);
    expect(result.iterations.slice(0, 3).every((row) => row.phase === 'rk4-starter')).toBe(true);
    expect(result.iterations[3].phase).toBe('milne-corrector');
    expect(result.iterations[3]).toHaveProperty('predictedY');
    expect(result.iterations[3]).toHaveProperty('correctedY');
    expect(result.warnings).toContain('Milne Predictor-Corrector Method used RK4 starter values for the first 4 points');
  });

  test('ODE services support xn-derived step counts', () => {
    const result = solveRK4({
      equation: 'x + y',
      x0: 0,
      y0: 1,
      h: 0.1,
      xn: 1,
      includeExplanation: false,
      includeGraphData: false,
    });

    expect(result.finalAnswer.stepsUsed).toBe(10);
    expect(result.explanation).toBeNull();
  });
});

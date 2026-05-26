'use strict';

const { solveLagrangeInterpolation } = require('../modules/solvers/interpolation/lagrange.service');
const { solveNewtonDividedDifference } = require('../modules/solvers/interpolation/newtonDividedDifference.service');
const { solveNaturalCubicSpline } = require('../modules/solvers/interpolation/naturalCubicSpline.service');
const { solveQuadraticInterpolation } = require('../modules/solvers/interpolation/quadraticInterpolation.service');

describe('Interpolation services', () => {
  test('Lagrange interpolation predicts a value and returns graph data', () => {
    const result = solveLagrangeInterpolation({
      points: [
        { x: 0, y: 1 },
        { x: 1, y: 3 },
        { x: 2, y: 2 },
      ],
      targetX: 1.5,
      includeExplanation: true,
      includeGraphData: true,
    });

    expect(result.method).toBe('Lagrange Interpolation');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.predictedY).toBeCloseTo(2.875, 6);
    expect(result.iterations).toHaveLength(3);
    expect(result.graphData.originalPoints).toHaveLength(3);
    expect(result.graphData.sampledCurve).toHaveLength(81);
    expect(result.graphData.predictedPoint).toEqual({ x: 1.5, y: 2.875 });
  });

  test('Newton divided difference builds table rows and predicts a value', () => {
    const result = solveNewtonDividedDifference({
      points: [
        { x: 0, y: 1 },
        { x: 1, y: 3 },
        { x: 2, y: 2 },
        { x: 3, y: 5 },
      ],
      targetX: 1.5,
      includeExplanation: true,
      includeGraphData: false,
    });

    expect(result.method).toBe('Newton Divided Difference');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.predictedY).toBeCloseTo(2.4375, 6);
    expect(result.finalAnswer.coefficients).toHaveLength(4);
    expect(result.iterations).toHaveLength(6);
    expect(result.graphData.predictedPoint).toBeNull();
  });

  test('Natural cubic spline uses interval coefficients and predicts a value', () => {
    const result = solveNaturalCubicSpline({
      points: [
        { x: 0, y: 0 },
        { x: 1, y: 1 },
        { x: 2, y: 0 },
        { x: 3, y: 1 },
      ],
      targetX: 1.5,
      includeExplanation: true,
      includeGraphData: true,
    });

    expect(result.method).toBe('Natural Cubic Spline');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.predictedY).toBeCloseTo(0.5, 6);
    expect(result.finalAnswer.intervalIndex).toBe(1);
    expect(result.iterations.some((row) => row.phase === 'interval-coefficients')).toBe(true);
    expect(result.warnings).toContain('Natural cubic spline uses zero second derivative at both endpoints');
  });

  test('Quadratic interpolation selects the 3 nearest points and fits y = ax^2 + bx + c', () => {
    const result = solveQuadraticInterpolation({
      points: [
        { x: 0, y: 1 },
        { x: 1, y: 4 },
        { x: 2, y: 9 },
        { x: 3, y: 16 },
      ],
      targetX: 1.5,
      includeExplanation: true,
      includeGraphData: true,
    });

    expect(result.method).toBe('Quadratic Interpolation');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.predictedY).toBeCloseTo(6.25, 6);
    expect(result.finalAnswer.coefficients.a).toBeCloseTo(1, 6);
    expect(result.finalAnswer.coefficients.b).toBeCloseTo(2, 6);
    expect(result.finalAnswer.coefficients.c).toBeCloseTo(1, 6);
    expect(result.finalAnswer.selectedPoints).toHaveLength(3);
    expect(result.warnings).toContain('Quadratic interpolation uses only the 3 nearest points to targetX');
  });

  test('Interpolation services warn when targetX is outside the point range', () => {
    const result = solveLagrangeInterpolation({
      points: [
        { x: 0, y: 1 },
        { x: 1, y: 3 },
      ],
      targetX: 2,
      includeExplanation: false,
      includeGraphData: false,
    });

    expect(result.warnings).toContain('targetX is outside the input point range; result is extrapolation');
    expect(result.explanation).toBeNull();
  });
});

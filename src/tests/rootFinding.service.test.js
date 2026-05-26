'use strict';

const { solveNewtonRaphson } = require('../modules/solvers/rootFinding/newtonRaphson.service');
const { solveSecant } = require('../modules/solvers/rootFinding/secant.service');
const { solveRegulaFalsi } = require('../modules/solvers/rootFinding/regulaFalsi.service');
const { AppError, errorCodes } = require('../common/errors');

describe('Root-finding services', () => {
  test('Newton-Raphson converges with an analytical derivative', () => {
    const result = solveNewtonRaphson({
      equation: 'x^3 - x - 2',
      derivativeEquation: '3*x^2 - 1',
      initialGuess: 1.5,
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
      includeGraphData: false,
    });

    expect(result.method).toBe('Newton-Raphson Method');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.root).toBeCloseTo(1.5214, 3);
    expect(result.iterations[0]).toHaveProperty('derivative');
    expect(result.graphData).toEqual([]);
  });

  test('Newton-Raphson uses numerical derivative when derivativeEquation is omitted', () => {
    const result = solveNewtonRaphson({
      equation: 'x^3 - x - 2',
      initialGuess: 1.5,
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: false,
      includeGraphData: false,
    });

    expect(result.status).toBe('converged');
    expect(result.warnings).toContain('No derivativeEquation provided; numerical derivative was used');
    expect(result.explanation).toBeNull();
  });

  test('Newton-Raphson returns failed when derivative is near zero', () => {
    const result = solveNewtonRaphson({
      equation: 'x^2',
      derivativeEquation: '2*x',
      initialGuess: 0,
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
      includeGraphData: false,
    });

    expect(result.status).toBe('failed');
    expect(result.finalAnswer.reason).toBe('Derivative near zero');
  });

  test('Secant converges for x^3 - x - 2', () => {
    const result = solveSecant({
      equation: 'x^3 - x - 2',
      firstGuess: 1,
      secondGuess: 2,
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
      includeGraphData: false,
    });

    expect(result.method).toBe('Secant Method');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.root).toBeCloseTo(1.5214, 3);
    expect(result.iterations[0]).toHaveProperty('xNext');
  });

  test('Secant returns failed when denominator is near zero', () => {
    const result = solveSecant({
      equation: 'x^2 + 1',
      firstGuess: -1,
      secondGuess: 1,
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
      includeGraphData: false,
    });

    expect(result.status).toBe('failed');
    expect(result.finalAnswer.reason).toBe('Secant denominator near zero');
  });

  test('Regula Falsi converges for x^3 - x - 2', () => {
    const result = solveRegulaFalsi({
      equation: 'x^3 - x - 2',
      lowerBound: 1,
      upperBound: 2,
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
      includeGraphData: false,
    });

    expect(result.method).toBe('Regula Falsi Method');
    expect(result.status).toBe('converged');
    expect(result.finalAnswer.root).toBeCloseTo(1.5214, 3);
    expect(result.iterations[0]).toHaveProperty('formulaTemplate');
  });

  test('Regula Falsi throws precondition error when interval does not bracket a root', () => {
    expect(() => solveRegulaFalsi({
      equation: 'x^2 + 1',
      lowerBound: -1,
      upperBound: 1,
      tolerance: 0.0001,
      maxIterations: 100,
      includeExplanation: true,
      includeGraphData: false,
    })).toThrow(AppError);

    try {
      solveRegulaFalsi({
        equation: 'x^2 + 1',
        lowerBound: -1,
        upperBound: 1,
        tolerance: 0.0001,
        maxIterations: 100,
        includeExplanation: true,
        includeGraphData: false,
      });
    } catch (err) {
      expect(err.code).toBe(errorCodes.SOLVER_PRECONDITION_FAILED);
    }
  });
});

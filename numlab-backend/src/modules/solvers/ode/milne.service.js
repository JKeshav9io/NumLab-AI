'use strict';

const { AppError, errorCodes } = require('../../../common/errors');
const { computeRK4Step } = require('./rk4.service');
const {
  buildExplanation,
  buildFinalAnswer,
  buildGraphData,
  buildInput,
  buildResult,
  compileDerivative,
  resolveSteps,
  round,
} = require('./ode.utils');

function solveMilne(params) {
  const start = Date.now();
  const { x0, y0, h, includeExplanation, includeGraphData } = params;
  const derivative = compileDerivative(params.equation);
  const steps = resolveSteps(params);

  if (steps < 4) {
    throw new AppError(
      'Milne Predictor-Corrector Method requires at least 4 steps',
      400,
      errorCodes.SOLVER_PRECONDITION_FAILED,
      { steps }
    );
  }

  const input = buildInput(params, steps);
  const iterations = [];
  const warnings = ['Milne Predictor-Corrector Method used RK4 starter values for the first 4 points'];
  const points = [{
    x: x0,
    y: y0,
    f: derivative(x0, y0),
  }];

  for (let step = 1; step <= 3; step++) {
    const previous = points[points.length - 1];
    const rk4Row = computeRK4Step(derivative, previous.x, previous.y, h, step);
    const nextPoint = {
      x: rk4Row.rawNextX,
      y: rk4Row.rawNextY,
      f: derivative(rk4Row.rawNextX, rk4Row.rawNextY),
    };

    iterations.push({
      step,
      phase: 'rk4-starter',
      x: rk4Row.x,
      y: rk4Row.y,
      k1: rk4Row.k1,
      k2: rk4Row.k2,
      k3: rk4Row.k3,
      k4: rk4Row.k4,
      nextX: rk4Row.nextX,
      nextY: rk4Row.nextY,
      formulaTemplate: rk4Row.formulaTemplate,
      substitution: rk4Row.substitution,
    });

    points.push(nextPoint);
  }

  for (let step = 4; step <= steps; step++) {
    const n = points.length - 1;
    const yNMinus3 = points[n - 3].y;
    const fNMinus2 = points[n - 2].f;
    const fNMinus1 = points[n - 1].f;
    const fN = points[n].f;
    const nextX = points[n].x + h;
    const predictedY = yNMinus3 + (4 * h / 3) * (2 * fN - fNMinus1 + 2 * fNMinus2);
    const predictedSlope = derivative(nextX, predictedY);
    const correctedY = points[n - 1].y + (h / 3) * (fNMinus1 + 4 * fN + predictedSlope);
    const correctedSlope = derivative(nextX, correctedY);

    iterations.push({
      step,
      phase: 'milne-corrector',
      x: round(points[n].x),
      y: round(points[n].y),
      nextX: round(nextX),
      fNMinus2: round(fNMinus2),
      fNMinus1: round(fNMinus1),
      fN: round(fN),
      predictedY: round(predictedY),
      predictedSlope: round(predictedSlope),
      correctedY: round(correctedY),
      formulaTemplate: 'predict: y_{n+1} = y_{n-3} + (4h/3)*(2f_n - f_{n-1} + 2f_{n-2}); correct: y_{n+1} = y_{n-1} + (h/3)*(f_{n-1} + 4f_n + f_{n+1})',
      substitution: `predictedY = ${round(predictedY)}, correctedY = ${round(correctedY)}`,
    });

    points.push({
      x: nextX,
      y: correctedY,
      f: correctedSlope,
    });
  }

  return buildResult({
    method: 'Milne Predictor-Corrector Method',
    input,
    iterations,
    finalAnswer: buildFinalAnswer(points[points.length - 1], steps),
    explanation: includeExplanation ? buildExplanation('Milne Predictor-Corrector Method', [
      'Generate the first 4 points using RK4 starter values.',
      'Predict the next value with Milne predictor formula.',
      'Correct the predicted value with the Milne-Simpson corrector formula.',
    ]) : null,
    graphData: includeGraphData ? buildGraphData(points) : [],
    warnings,
    start,
  });
}

module.exports = {
  solveMilne,
  milne: solveMilne,
};

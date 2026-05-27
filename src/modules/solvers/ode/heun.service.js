'use strict';

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

function solveHeun(params) {
  const start = Date.now();
  const { x0, y0, h, includeExplanation, includeGraphData } = params;
  const derivative = compileDerivative(params.equation);
  const steps = resolveSteps(params);
  const input = buildInput(params, steps);
  const iterations = [];
  const warnings = [];
  const points = [{ x: x0, y: y0 }];

  let x = x0;
  let y = y0;

  for (let step = 1; step <= steps; step++) {
    const k1 = derivative(x, y);
    const nextX = x + h;
    const predictor = y + h * k1;
    const k2 = derivative(nextX, predictor);
    const correctedY = y + (h / 2) * (k1 + k2);

    iterations.push({
      step,
      x: round(x),
      y: round(y),
      k1: round(k1),
      predictor: round(predictor),
      k2: round(k2),
      nextX: round(nextX),
      correctedY: round(correctedY),
      formulaTemplate: 'y_corrected = y + (h / 2) * (k1 + k2)',
      substitution: `y_corrected = ${round(y)} + (${round(h)} / 2) * (${round(k1)} + ${round(k2)}) = ${round(correctedY)}`,
    });

    x = nextX;
    y = correctedY;
    points.push({ x, y });
  }

  return buildResult({
    method: 'Heun / Improved Euler Method',
    input,
    iterations,
    finalAnswer: buildFinalAnswer(points[points.length - 1], steps),
    explanation: includeExplanation ? buildExplanation('Heun / Improved Euler Method', [
      'Use Euler prediction to estimate the next y value.',
      'Evaluate a second slope at the predicted point.',
      'Average the starting and predicted slopes to correct the next y value.',
    ]) : null,
    graphData: includeGraphData ? buildGraphData(points) : [],
    warnings,
    start,
  });
}

module.exports = {
  solveHeun,
  heun: solveHeun,
};

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

function solveEuler(params) {
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
    const slope = derivative(x, y);
    const nextX = x + h;
    const nextY = y + h * slope;

    iterations.push({
      step,
      x: round(x),
      y: round(y),
      fXY: round(slope),
      nextX: round(nextX),
      nextY: round(nextY),
      formulaTemplate: 'y_next = y + h * f(x, y)',
      substitution: `y_next = ${round(y)} + ${round(h)} * ${round(slope)} = ${round(nextY)}`,
    });

    x = nextX;
    y = nextY;
    points.push({ x, y });
  }

  return buildResult({
    method: 'Euler Method',
    input,
    iterations,
    finalAnswer: buildFinalAnswer(points[points.length - 1], steps),
    explanation: includeExplanation ? buildExplanation('Euler Method', [
      'Evaluate the slope f(x, y) at the current point.',
      'Advance y using y_next = y + h * f(x, y).',
      'Repeat until the requested number of steps is complete.',
    ]) : null,
    graphData: includeGraphData ? buildGraphData(points) : [],
    warnings,
    start,
  });
}

module.exports = {
  solveEuler,
  euler: solveEuler,
};

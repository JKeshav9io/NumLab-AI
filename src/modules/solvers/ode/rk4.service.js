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

function solveRK4(params) {
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
    const row = computeRK4Step(derivative, x, y, h, step);

    iterations.push(row);

    x = row.rawNextX;
    y = row.rawNextY;
    points.push({ x, y });
  }

  return buildResult({
    method: 'RK4 Method',
    input,
    iterations: iterations.map(stripRawValues),
    finalAnswer: buildFinalAnswer(points[points.length - 1], steps),
    explanation: includeExplanation ? buildExplanation('RK4 Method', [
      'Compute four slopes across the current step.',
      'Weight the two midpoint slopes twice.',
      'Advance y using the weighted average slope.',
    ]) : null,
    graphData: includeGraphData ? buildGraphData(points) : [],
    warnings,
    start,
  });
}

function computeRK4Step(derivative, x, y, h, step) {
  const k1 = derivative(x, y);
  const k2 = derivative(x + h / 2, y + (h * k1) / 2);
  const k3 = derivative(x + h / 2, y + (h * k2) / 2);
  const k4 = derivative(x + h, y + h * k3);
  const nextX = x + h;
  const nextY = y + (h / 6) * (k1 + 2 * k2 + 2 * k3 + k4);

  return {
    step,
    x: round(x),
    y: round(y),
    k1: round(k1),
    k2: round(k2),
    k3: round(k3),
    k4: round(k4),
    nextX: round(nextX),
    nextY: round(nextY),
    formulaTemplate: 'y_next = y + (h / 6) * (k1 + 2*k2 + 2*k3 + k4)',
    substitution: `y_next = ${round(y)} + (${round(h)} / 6) * (${round(k1)} + 2*${round(k2)} + 2*${round(k3)} + ${round(k4)}) = ${round(nextY)}`,
    rawNextX: nextX,
    rawNextY: nextY,
  };
}

function stripRawValues(row) {
  const { rawNextX, rawNextY, ...publicRow } = row;
  return publicRow;
}

module.exports = {
  computeRK4Step,
  solveRK4,
  rk4: solveRK4,
};

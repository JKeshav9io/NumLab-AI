'use strict';

const {
  buildExplanation,
  buildFinalAnswer,
  buildGraphData,
  buildInput,
  buildRangeWarnings,
  buildResult,
  emptyGraphData,
  round,
  roundPoint,
  sortPoints,
} = require('./interpolation.utils');

function solveNaturalCubicSpline(params) {
  const start = Date.now();
  const { targetX, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const warnings = buildRangeWarnings(points, targetX);
  warnings.push('Natural cubic spline uses zero second derivative at both endpoints');

  const spline = buildNaturalSpline(points);
  const intervalIndex = findInterval(points, targetX);
  const predictedY = evaluateSpline(spline, targetX);
  const iterations = buildIterations(points, spline, intervalIndex, targetX, predictedY);

  return buildResult({
    method: 'Natural Cubic Spline',
    input: buildInput(points, targetX),
    iterations,
    finalAnswer: {
      ...buildFinalAnswer(targetX, predictedY),
      intervalIndex,
      interval: {
        from: roundPoint(points[intervalIndex]),
        to: roundPoint(points[intervalIndex + 1]),
      },
    },
    explanation: includeExplanation ? buildExplanation('Natural Cubic Spline', [
      'Compute interval widths between sorted x values.',
      'Solve the natural spline tridiagonal system with endpoint second derivatives set to zero.',
      'Build one cubic polynomial for each interval and evaluate the interval containing targetX.',
    ]) : null,
    graphData: includeGraphData
      ? buildGraphData(points, targetX, predictedY, (x) => evaluateSpline(spline, x))
      : emptyGraphData(),
    warnings,
    start,
  });
}

function buildNaturalSpline(points) {
  const n = points.length;
  const a = points.map((point) => point.y);
  const b = Array(n - 1).fill(0);
  const c = Array(n).fill(0);
  const d = Array(n - 1).fill(0);
  const h = Array(n - 1).fill(0);
  const alpha = Array(n).fill(0);
  const l = Array(n).fill(0);
  const mu = Array(n).fill(0);
  const z = Array(n).fill(0);

  for (let i = 0; i < n - 1; i++) {
    h[i] = points[i + 1].x - points[i].x;
  }

  for (let i = 1; i < n - 1; i++) {
    alpha[i] = (3 / h[i]) * (a[i + 1] - a[i]) - (3 / h[i - 1]) * (a[i] - a[i - 1]);
  }

  l[0] = 1;
  mu[0] = 0;
  z[0] = 0;

  for (let i = 1; i < n - 1; i++) {
    l[i] = 2 * (points[i + 1].x - points[i - 1].x) - h[i - 1] * mu[i - 1];
    mu[i] = h[i] / l[i];
    z[i] = (alpha[i] - h[i - 1] * z[i - 1]) / l[i];
  }

  l[n - 1] = 1;
  z[n - 1] = 0;
  c[n - 1] = 0;

  for (let j = n - 2; j >= 0; j--) {
    c[j] = z[j] - mu[j] * c[j + 1];
    b[j] = ((a[j + 1] - a[j]) / h[j]) - (h[j] * (c[j + 1] + 2 * c[j]) / 3);
    d[j] = (c[j + 1] - c[j]) / (3 * h[j]);
  }

  const intervals = [];

  for (let i = 0; i < n - 1; i++) {
    intervals.push({
      index: i,
      xStart: points[i].x,
      xEnd: points[i + 1].x,
      a: a[i],
      b: b[i],
      c: c[i],
      d: d[i],
      h: h[i],
    });
  }

  return { intervals, h, alpha, l, mu, z };
}

function evaluateSpline(spline, x) {
  const interval = findSplineInterval(spline.intervals, x);
  const dx = x - interval.xStart;

  return interval.a + interval.b * dx + interval.c * dx ** 2 + interval.d * dx ** 3;
}

function findInterval(points, x) {
  if (x <= points[0].x) {
    return 0;
  }

  for (let i = 0; i < points.length - 1; i++) {
    if (x >= points[i].x && x <= points[i + 1].x) {
      return i;
    }
  }

  return points.length - 2;
}

function findSplineInterval(intervals, x) {
  if (x <= intervals[0].xStart) {
    return intervals[0];
  }

  for (const interval of intervals) {
    if (x >= interval.xStart && x <= interval.xEnd) {
      return interval;
    }
  }

  return intervals[intervals.length - 1];
}

function buildIterations(points, spline, intervalIndex, targetX, predictedY) {
  const iterations = [];

  spline.h.forEach((h, index) => {
    iterations.push({
      step: iterations.length + 1,
      phase: 'interval-setup',
      intervalIndex: index,
      from: roundPoint(points[index]),
      to: roundPoint(points[index + 1]),
      h: round(h),
    });
  });

  for (let i = 1; i < points.length - 1; i++) {
    iterations.push({
      step: iterations.length + 1,
      phase: 'tridiagonal-system',
      row: i,
      alpha: round(spline.alpha[i]),
      l: round(spline.l[i]),
      mu: round(spline.mu[i]),
      z: round(spline.z[i]),
      formulaTemplate: 'natural cubic spline tridiagonal row',
    });
  }

  spline.intervals.forEach((interval) => {
    iterations.push({
      step: iterations.length + 1,
      phase: 'interval-coefficients',
      intervalIndex: interval.index,
      range: [round(interval.xStart), round(interval.xEnd)],
      coefficients: {
        a: round(interval.a),
        b: round(interval.b),
        c: round(interval.c),
        d: round(interval.d),
      },
      formulaTemplate: 'S_i(x) = a_i + b_i*(x-x_i) + c_i*(x-x_i)^2 + d_i*(x-x_i)^3',
    });
  });

  iterations.push({
    step: iterations.length + 1,
    phase: 'evaluate',
    intervalIndex,
    targetX: round(targetX),
    predictedY: round(predictedY),
    formulaTemplate: 'S_i(x) = a_i + b_i*(x-x_i) + c_i*(x-x_i)^2 + d_i*(x-x_i)^3',
    substitution: `Evaluated interval ${intervalIndex} at x = ${round(targetX)} to get ${round(predictedY)}`,
  });

  return iterations;
}

module.exports = {
  solveNaturalCubicSpline,
  naturalCubicSpline: solveNaturalCubicSpline,
};

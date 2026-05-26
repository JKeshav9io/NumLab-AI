'use strict';

const { AppError, errorCodes } = require('../../../common/errors');
const {
  buildDifferenceTable,
  buildExplanation,
  buildFinalAnswer,
  buildForwardDifferenceMatrix,
  buildGraphData,
  buildInput,
  buildPreferenceWarnings,
  buildRangeWarnings,
  buildResult,
  emptyGraphData,
  evaluateNewtonBackwardFromMatrix,
  evaluateNewtonForwardFromMatrix,
  getEqualSpacing,
  round,
  roundPoint,
  sortPoints,
} = require('./interpolation.utils');

const BESSEL_MIDPOINT_TOLERANCE_FACTOR = 0.25;

function solveCentralDifferenceInterpolation(params) {
  const start = Date.now();
  const { targetX, variant, includeExplanation, includeGraphData } = params;
  const points = sortPoints(params.points);
  const matrix = buildForwardDifferenceMatrix(points);
  const differenceTable = buildDifferenceTable(points, matrix);
  const h = getEqualSpacing(points);
  const centerIndex = findNearestPointIndex(points, targetX);
  const warnings = [
    ...buildRangeWarnings(points, targetX),
    ...buildPreferenceWarnings(points, targetX, 'central-difference'),
    ...buildVariantWarnings(points, targetX, variant, centerIndex),
  ];
  const evaluator = chooseEvaluator(points, matrix, targetX, variant);
  const predictedY = evaluator(targetX);
  const iterations = buildCentralSteps({
    points,
    targetX,
    variant,
    centerIndex,
    h,
    predictedY,
    evaluationDirection: evaluator.direction,
  });

  return buildResult({
    method: 'Central Difference Interpolation',
    input: {
      ...buildInput(points, targetX),
      stepSize: round(h),
      variant,
      centerIndex,
    },
    iterations,
    finalAnswer: {
      ...buildFinalAnswer(targetX, predictedY),
      variant,
      center: roundPoint(points[centerIndex]),
    },
    explanation: includeExplanation ? buildExplanation('Central Difference Interpolation', [
      'Sort the points and verify equal spacing.',
      'Build the finite difference table.',
      'Choose the requested central-difference variant and evaluate from the generated table.',
    ]) : null,
    graphData: includeGraphData
      ? buildGraphData(points, targetX, predictedY, (x) => evaluator(x))
      : emptyGraphData(),
    warnings,
    start,
    extra: { differenceTable },
  });
}

function chooseEvaluator(points, matrix, targetX, variant) {
  if (variant === 'bessel') {
    validateBesselSuitability(points, targetX);
  }

  if (variant === 'gauss-backward') {
    const evaluator = (x) => evaluateNewtonBackwardFromMatrix(points, matrix, x);
    evaluator.direction = 'backward';
    return evaluator;
  }

  const evaluator = (x) => evaluateNewtonForwardFromMatrix(points, matrix, x);
  evaluator.direction = 'forward';
  return evaluator;
}

function validateBesselSuitability(points, targetX) {
  const h = getEqualSpacing(points);
  const intervalIndex = findContainingInterval(points, targetX);

  if (intervalIndex <= 0 || intervalIndex >= points.length - 2) {
    throw new AppError(
      'Bessel interpolation requires targetX to be near an interior midpoint',
      400,
      errorCodes.SOLVER_PRECONDITION_FAILED,
      { targetX: round(targetX) }
    );
  }

  const midpoint = (points[intervalIndex].x + points[intervalIndex + 1].x) / 2;

  if (Math.abs(targetX - midpoint) > Math.abs(h) * BESSEL_MIDPOINT_TOLERANCE_FACTOR) {
    throw new AppError(
      'Bessel interpolation is suitable only when targetX is near the midpoint between two central points',
      400,
      errorCodes.SOLVER_PRECONDITION_FAILED,
      {
        targetX: round(targetX),
        nearestMidpoint: round(midpoint),
      }
    );
  }
}

function findNearestPointIndex(points, targetX) {
  let nearestIndex = 0;

  for (let index = 1; index < points.length; index++) {
    if (Math.abs(points[index].x - targetX) < Math.abs(points[nearestIndex].x - targetX)) {
      nearestIndex = index;
    }
  }

  return nearestIndex;
}

function findContainingInterval(points, targetX) {
  for (let index = 0; index < points.length - 1; index++) {
    if (targetX >= points[index].x && targetX <= points[index + 1].x) {
      return index;
    }
  }

  return targetX < points[0].x ? 0 : points.length - 2;
}

function buildVariantWarnings(points, targetX, variant, centerIndex) {
  const warnings = [];
  const centerX = points[centerIndex].x;
  const h = Math.abs(getEqualSpacing(points));

  if (variant === 'gauss-forward' && targetX < centerX) {
    warnings.push('Gauss Forward is usually preferred when targetX is at or after the center point');
  }

  if (variant === 'gauss-backward' && targetX > centerX) {
    warnings.push('Gauss Backward is usually preferred when targetX is at or before the center point');
  }

  if (variant === 'stirling' && Math.abs(targetX - centerX) > h / 2) {
    warnings.push('Stirling interpolation is usually preferred very close to the center point');
  }

  return warnings;
}

function buildCentralSteps({ points, targetX, variant, centerIndex, h, predictedY, evaluationDirection }) {
  const p = (targetX - points[centerIndex].x) / h;

  return [
    {
      step: 1,
      phase: 'select-center',
      centerIndex,
      center: roundPoint(points[centerIndex]),
      targetX: round(targetX),
      stepSize: round(h),
    },
    {
      step: 2,
      phase: 'select-variant',
      variant,
      evaluationDirection,
      description: `${variant} selected for central-difference interpolation`,
    },
    {
      step: 3,
      phase: 'compute-p',
      p: round(p),
      formulaTemplate: 'p = (x - x_center) / h',
      substitution: `p = (${round(targetX)} - ${round(points[centerIndex].x)}) / ${round(h)} = ${round(p)}`,
    },
    {
      step: 4,
      phase: 'evaluate',
      predictedY: round(predictedY),
      formulaTemplate: 'finite-difference polynomial from the generated difference table',
      substitution: `Evaluated ${variant} structure at x = ${round(targetX)} to get ${round(predictedY)}`,
    },
  ];
}

module.exports = {
  solveCentralDifferenceInterpolation,
  centralDifferenceInterpolation: solveCentralDifferenceInterpolation,
};

'use strict';

const { solveLagrangeInterpolation } = require('./lagrange.service');
const { solveNewtonDividedDifference } = require('./newtonDividedDifference.service');
const { solveNewtonForwardInterpolation } = require('./newtonForward.service');
const { solveNewtonBackwardInterpolation } = require('./newtonBackward.service');
const { solveCentralDifferenceInterpolation } = require('./centralDifference.service');
const { solveNaturalCubicSpline } = require('./naturalCubicSpline.service');
const { solveQuadraticInterpolation } = require('./quadraticInterpolation.service');

module.exports = {
  solveLagrangeInterpolation,
  solveNewtonDividedDifference,
  solveNewtonForwardInterpolation,
  solveNewtonBackwardInterpolation,
  solveCentralDifferenceInterpolation,
  solveNaturalCubicSpline,
  solveQuadraticInterpolation,
};

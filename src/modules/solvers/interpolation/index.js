'use strict';

const { solveLagrangeInterpolation } = require('./lagrange.service');
const { solveNewtonDividedDifference } = require('./newtonDividedDifference.service');
const { solveNaturalCubicSpline } = require('./naturalCubicSpline.service');
const { solveQuadraticInterpolation } = require('./quadraticInterpolation.service');

module.exports = {
  solveLagrangeInterpolation,
  solveNewtonDividedDifference,
  solveNaturalCubicSpline,
  solveQuadraticInterpolation,
};

'use strict';

const { solveForwardDifference } = require('./forwardDifference.service');
const { solveBackwardDifference } = require('./backwardDifference.service');
const { solveCentralDifference } = require('./centralDifference.service');
const { solveLagrangeDifferentiation } = require('./lagrangeDifferentiation.service');
const { solveFunctionFiniteDifference } = require('./functionFiniteDifference.service');

module.exports = {
  solveForwardDifference,
  solveBackwardDifference,
  solveCentralDifference,
  solveLagrangeDifferentiation,
  solveFunctionFiniteDifference,
};

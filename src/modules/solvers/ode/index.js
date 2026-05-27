'use strict';

const { solveEuler } = require('./euler.service');
const { solveHeun } = require('./heun.service');
const { solveRK4 } = require('./rk4.service');
const { solveMilne } = require('./milne.service');

module.exports = {
  solveEuler,
  solveHeun,
  solveRK4,
  solveMilne,
};

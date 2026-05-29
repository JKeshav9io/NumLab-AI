'use strict';

const { solveTrapezoidal } = require('./trapezoidal.service');
const { solveSimpsonOneThird } = require('./simpsonOneThird.service');
const { solveSimpsonThreeEighth } = require('./simpsonThreeEighth.service');
const { solveGaussLegendre } = require('./gaussLegendre.service');

module.exports = {
  solveTrapezoidal,
  solveSimpsonOneThird,
  solveSimpsonThreeEighth,
  solveGaussLegendre,
};

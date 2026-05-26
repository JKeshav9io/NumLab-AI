'use strict';

const logger = require('../../config/logger');
const { solveBisection } = require('./rootFinding/bisection.service');
const { solveNewtonRaphson } = require('./rootFinding/newtonRaphson.service');
const { solveSecant } = require('./rootFinding/secant.service');
const { solveRegulaFalsi } = require('./rootFinding/regulaFalsi.service');
const { solveGaussElimination } = require('./linearAlgebra/gaussElimination.service');
const { solveJacobi } = require('./linearAlgebra/jacobi.service');
const { solveGaussSeidel } = require('./linearAlgebra/gaussSeidel.service');
const { solveLagrangeInterpolation } = require('./interpolation/lagrange.service');
const { solveNewtonDividedDifference } = require('./interpolation/newtonDividedDifference.service');
const { solveNewtonForwardInterpolation } = require('./interpolation/newtonForward.service');
const { solveNewtonBackwardInterpolation } = require('./interpolation/newtonBackward.service');
const { solveCentralDifferenceInterpolation } = require('./interpolation/centralDifference.service');
const { solveNaturalCubicSpline } = require('./interpolation/naturalCubicSpline.service');
const { solveQuadraticInterpolation } = require('./interpolation/quadraticInterpolation.service');

function runBisection(params, context = {}) {
  return runRootSolver('root/bisection', solveBisection, params, context);
}

function runNewtonRaphson(params, context = {}) {
  return runRootSolver('root/newton', solveNewtonRaphson, params, context);
}

function runSecant(params, context = {}) {
  return runRootSolver('root/secant', solveSecant, params, context);
}

function runRegulaFalsi(params, context = {}) {
  return runRootSolver('root/regula-falsi', solveRegulaFalsi, params, context);
}

function runGaussElimination(params, context = {}) {
  return runSolver('linear/gauss-elimination', solveGaussElimination, params, context);
}

function runJacobi(params, context = {}) {
  return runSolver('linear/jacobi', solveJacobi, params, context);
}

function runGaussSeidel(params, context = {}) {
  return runSolver('linear/gauss-seidel', solveGaussSeidel, params, context);
}

function runLagrangeInterpolation(params, context = {}) {
  return runSolver('interpolation/lagrange', solveLagrangeInterpolation, params, context);
}

function runNewtonDividedDifference(params, context = {}) {
  return runSolver('interpolation/newton-divided-difference', solveNewtonDividedDifference, params, context);
}

function runNewtonForwardInterpolation(params, context = {}) {
  return runSolver('interpolation/newton-forward', solveNewtonForwardInterpolation, params, context);
}

function runNewtonBackwardInterpolation(params, context = {}) {
  return runSolver('interpolation/newton-backward', solveNewtonBackwardInterpolation, params, context);
}

function runCentralDifferenceInterpolation(params, context = {}) {
  return runSolver('interpolation/central-difference', solveCentralDifferenceInterpolation, params, context);
}

function runNaturalCubicSpline(params, context = {}) {
  return runSolver('interpolation/natural-cubic-spline', solveNaturalCubicSpline, params, context);
}

function runQuadraticInterpolation(params, context = {}) {
  return runSolver('interpolation/quadratic', solveQuadraticInterpolation, params, context);
}

function runRootSolver(method, solver, params, context) {
  return runSolver(method, solver, params, context);
}

function runSolver(method, solver, params, context) {
  const result = solver(params);

  logger.info({
    requestId: context.requestId,
    method,
    status: result.status,
    executionTimeMs: result.executionTimeMs,
    iterationCount: result.iterations.length,
    warningCount: result.warnings.length,
  }, 'Solve completed');

  return result;
}

module.exports = {
  runBisection,
  runNewtonRaphson,
  runSecant,
  runRegulaFalsi,
  runGaussElimination,
  runJacobi,
  runGaussSeidel,
  runLagrangeInterpolation,
  runNewtonDividedDifference,
  runNewtonForwardInterpolation,
  runNewtonBackwardInterpolation,
  runCentralDifferenceInterpolation,
  runNaturalCubicSpline,
  runQuadraticInterpolation,
};

'use strict';

const solversService = require('./solvers.service');
const {
  validateBisection,
  validateNewtonRaphson,
  validateSecant,
  validateRegulaFalsi,
  validateGaussElimination,
  validateJacobi,
  validateGaussSeidel,
  validateLagrangeInterpolation,
  validateNewtonDividedDifference,
  validateNewtonForwardInterpolation,
  validateNewtonBackwardInterpolation,
  validateCentralDifferenceInterpolation,
  validateNaturalCubicSpline,
  validateQuadraticInterpolation,
  validateEulerODE,
  validateHeunODE,
  validateRK4ODE,
  validateMilneODE,
} = require('./solvers.validator');
const { sendSuccess } = require('../../common/utils');

function solveBisection(req, res) {
  const params = validateBisection(req.body);
  const result = solversService.runBisection(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveNewtonRaphson(req, res) {
  const params = validateNewtonRaphson(req.body);
  const result = solversService.runNewtonRaphson(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveSecant(req, res) {
  const params = validateSecant(req.body);
  const result = solversService.runSecant(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveRegulaFalsi(req, res) {
  const params = validateRegulaFalsi(req.body);
  const result = solversService.runRegulaFalsi(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveGaussElimination(req, res) {
  const params = validateGaussElimination(req.body);
  const result = solversService.runGaussElimination(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveJacobi(req, res) {
  const params = validateJacobi(req.body);
  const result = solversService.runJacobi(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveGaussSeidel(req, res) {
  const params = validateGaussSeidel(req.body);
  const result = solversService.runGaussSeidel(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveLagrangeInterpolation(req, res) {
  const params = validateLagrangeInterpolation(req.body);
  const result = solversService.runLagrangeInterpolation(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveNewtonDividedDifference(req, res) {
  const params = validateNewtonDividedDifference(req.body);
  const result = solversService.runNewtonDividedDifference(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveNewtonForwardInterpolation(req, res) {
  const params = validateNewtonForwardInterpolation(req.body);
  const result = solversService.runNewtonForwardInterpolation(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveNewtonBackwardInterpolation(req, res) {
  const params = validateNewtonBackwardInterpolation(req.body);
  const result = solversService.runNewtonBackwardInterpolation(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveCentralDifferenceInterpolation(req, res) {
  const params = validateCentralDifferenceInterpolation(req.body);
  const result = solversService.runCentralDifferenceInterpolation(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveNaturalCubicSpline(req, res) {
  const params = validateNaturalCubicSpline(req.body);
  const result = solversService.runNaturalCubicSpline(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveQuadraticInterpolation(req, res) {
  const params = validateQuadraticInterpolation(req.body);
  const result = solversService.runQuadraticInterpolation(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveEulerODE(req, res) {
  const params = validateEulerODE(req.body);
  const result = solversService.runEulerODE(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveHeunODE(req, res) {
  const params = validateHeunODE(req.body);
  const result = solversService.runHeunODE(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveRK4ODE(req, res) {
  const params = validateRK4ODE(req.body);
  const result = solversService.runRK4ODE(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

function solveMilneODE(req, res) {
  const params = validateMilneODE(req.body);
  const result = solversService.runMilneODE(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

module.exports = {
  solveBisection,
  solveNewtonRaphson,
  solveSecant,
  solveRegulaFalsi,
  solveGaussElimination,
  solveJacobi,
  solveGaussSeidel,
  solveLagrangeInterpolation,
  solveNewtonDividedDifference,
  solveNewtonForwardInterpolation,
  solveNewtonBackwardInterpolation,
  solveCentralDifferenceInterpolation,
  solveNaturalCubicSpline,
  solveQuadraticInterpolation,
  solveEulerODE,
  solveHeunODE,
  solveRK4ODE,
  solveMilneODE,
};

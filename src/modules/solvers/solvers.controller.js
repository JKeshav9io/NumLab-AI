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
  validateTrapezoidalIntegration,
  validateSimpsonOneThirdIntegration,
  validateSimpsonThreeEighthIntegration,
  validateGaussLegendreIntegration,
  validateForwardDifference,
  validateBackwardDifference,
  validateCentralDifference,
  validateLagrangeDifferentiation,
  validateFunctionFiniteDifference,
} = require('./solvers.validator');
const { sendSuccess } = require('../../common/utils');

/**
 * Extracts execution context from Express request (request ID and optional authenticated user ID).
 * @param {import('express').Request} req
 * @returns {{ requestId: string, userId: string|null }}
 */
function extractContext(req) {
  return {
    requestId: req.id,
    userId: req.user?.id || null,
  };
}

function solveBisection(req, res) {
  const params = validateBisection(req.body);
  const result = solversService.runBisection(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveNewtonRaphson(req, res) {
  const params = validateNewtonRaphson(req.body);
  const result = solversService.runNewtonRaphson(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveSecant(req, res) {
  const params = validateSecant(req.body);
  const result = solversService.runSecant(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveRegulaFalsi(req, res) {
  const params = validateRegulaFalsi(req.body);
  const result = solversService.runRegulaFalsi(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveGaussElimination(req, res) {
  const params = validateGaussElimination(req.body);
  const result = solversService.runGaussElimination(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveJacobi(req, res) {
  const params = validateJacobi(req.body);
  const result = solversService.runJacobi(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveGaussSeidel(req, res) {
  const params = validateGaussSeidel(req.body);
  const result = solversService.runGaussSeidel(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveLagrangeInterpolation(req, res) {
  const params = validateLagrangeInterpolation(req.body);
  const result = solversService.runLagrangeInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveNewtonDividedDifference(req, res) {
  const params = validateNewtonDividedDifference(req.body);
  const result = solversService.runNewtonDividedDifference(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveNewtonForwardInterpolation(req, res) {
  const params = validateNewtonForwardInterpolation(req.body);
  const result = solversService.runNewtonForwardInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveNewtonBackwardInterpolation(req, res) {
  const params = validateNewtonBackwardInterpolation(req.body);
  const result = solversService.runNewtonBackwardInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveCentralDifferenceInterpolation(req, res) {
  const params = validateCentralDifferenceInterpolation(req.body);
  const result = solversService.runCentralDifferenceInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveNaturalCubicSpline(req, res) {
  const params = validateNaturalCubicSpline(req.body);
  const result = solversService.runNaturalCubicSpline(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveQuadraticInterpolation(req, res) {
  const params = validateQuadraticInterpolation(req.body);
  const result = solversService.runQuadraticInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveEulerODE(req, res) {
  const params = validateEulerODE(req.body);
  const result = solversService.runEulerODE(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveHeunODE(req, res) {
  const params = validateHeunODE(req.body);
  const result = solversService.runHeunODE(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveRK4ODE(req, res) {
  const params = validateRK4ODE(req.body);
  const result = solversService.runRK4ODE(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveMilneODE(req, res) {
  const params = validateMilneODE(req.body);
  const result = solversService.runMilneODE(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveTrapezoidalIntegration(req, res) {
  const params = validateTrapezoidalIntegration(req.body);
  const result = solversService.runTrapezoidalIntegration(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveSimpsonOneThirdIntegration(req, res) {
  const params = validateSimpsonOneThirdIntegration(req.body);
  const result = solversService.runSimpsonOneThirdIntegration(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveSimpsonThreeEighthIntegration(req, res) {
  const params = validateSimpsonThreeEighthIntegration(req.body);
  const result = solversService.runSimpsonThreeEighthIntegration(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveGaussLegendreIntegration(req, res) {
  const params = validateGaussLegendreIntegration(req.body);
  const result = solversService.runGaussLegendreIntegration(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveForwardDifference(req, res) {
  const params = validateForwardDifference(req.body);
  const result = solversService.runForwardDifference(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveBackwardDifference(req, res) {
  const params = validateBackwardDifference(req.body);
  const result = solversService.runBackwardDifference(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveCentralDifference(req, res) {
  const params = validateCentralDifference(req.body);
  const result = solversService.runCentralDifference(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveLagrangeDifferentiation(req, res) {
  const params = validateLagrangeDifferentiation(req.body);
  const result = solversService.runLagrangeDifferentiation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

function solveFunctionFiniteDifference(req, res) {
  const params = validateFunctionFiniteDifference(req.body);
  const result = solversService.runFunctionFiniteDifference(params, extractContext(req));

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
  solveTrapezoidalIntegration,
  solveSimpsonOneThirdIntegration,
  solveSimpsonThreeEighthIntegration,
  solveGaussLegendreIntegration,
  solveForwardDifference,
  solveBackwardDifference,
  solveCentralDifference,
  solveLagrangeDifferentiation,
  solveFunctionFiniteDifference,
};

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

async function solveBisection(req, res) {
  const params = validateBisection(req.body);
  const result = await solversService.runBisection(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveNewtonRaphson(req, res) {
  const params = validateNewtonRaphson(req.body);
  const result = await solversService.runNewtonRaphson(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveSecant(req, res) {
  const params = validateSecant(req.body);
  const result = await solversService.runSecant(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveRegulaFalsi(req, res) {
  const params = validateRegulaFalsi(req.body);
  const result = await solversService.runRegulaFalsi(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveGaussElimination(req, res) {
  const params = validateGaussElimination(req.body);
  const result = await solversService.runGaussElimination(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveJacobi(req, res) {
  const params = validateJacobi(req.body);
  const result = await solversService.runJacobi(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveGaussSeidel(req, res) {
  const params = validateGaussSeidel(req.body);
  const result = await solversService.runGaussSeidel(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveLagrangeInterpolation(req, res) {
  const params = validateLagrangeInterpolation(req.body);
  const result = await solversService.runLagrangeInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveNewtonDividedDifference(req, res) {
  const params = validateNewtonDividedDifference(req.body);
  const result = await solversService.runNewtonDividedDifference(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveNewtonForwardInterpolation(req, res) {
  const params = validateNewtonForwardInterpolation(req.body);
  const result = await solversService.runNewtonForwardInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveNewtonBackwardInterpolation(req, res) {
  const params = validateNewtonBackwardInterpolation(req.body);
  const result = await solversService.runNewtonBackwardInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveCentralDifferenceInterpolation(req, res) {
  const params = validateCentralDifferenceInterpolation(req.body);
  const result = await solversService.runCentralDifferenceInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveNaturalCubicSpline(req, res) {
  const params = validateNaturalCubicSpline(req.body);
  const result = await solversService.runNaturalCubicSpline(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveQuadraticInterpolation(req, res) {
  const params = validateQuadraticInterpolation(req.body);
  const result = await solversService.runQuadraticInterpolation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveEulerODE(req, res) {
  const params = validateEulerODE(req.body);
  const result = await solversService.runEulerODE(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveHeunODE(req, res) {
  const params = validateHeunODE(req.body);
  const result = await solversService.runHeunODE(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveRK4ODE(req, res) {
  const params = validateRK4ODE(req.body);
  const result = await solversService.runRK4ODE(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveMilneODE(req, res) {
  const params = validateMilneODE(req.body);
  const result = await solversService.runMilneODE(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveTrapezoidalIntegration(req, res) {
  const params = validateTrapezoidalIntegration(req.body);
  const result = await solversService.runTrapezoidalIntegration(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveSimpsonOneThirdIntegration(req, res) {
  const params = validateSimpsonOneThirdIntegration(req.body);
  const result = await solversService.runSimpsonOneThirdIntegration(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveSimpsonThreeEighthIntegration(req, res) {
  const params = validateSimpsonThreeEighthIntegration(req.body);
  const result = await solversService.runSimpsonThreeEighthIntegration(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveGaussLegendreIntegration(req, res) {
  const params = validateGaussLegendreIntegration(req.body);
  const result = await solversService.runGaussLegendreIntegration(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveForwardDifference(req, res) {
  const params = validateForwardDifference(req.body);
  const result = await solversService.runForwardDifference(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveBackwardDifference(req, res) {
  const params = validateBackwardDifference(req.body);
  const result = await solversService.runBackwardDifference(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveCentralDifference(req, res) {
  const params = validateCentralDifference(req.body);
  const result = await solversService.runCentralDifference(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveLagrangeDifferentiation(req, res) {
  const params = validateLagrangeDifferentiation(req.body);
  const result = await solversService.runLagrangeDifferentiation(params, extractContext(req));

  return sendSuccess(res, result, req.id);
}

async function solveFunctionFiniteDifference(req, res) {
  const params = validateFunctionFiniteDifference(req.body);
  const result = await solversService.runFunctionFiniteDifference(params, extractContext(req));

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

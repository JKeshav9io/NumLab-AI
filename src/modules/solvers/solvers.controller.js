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

module.exports = {
  solveBisection,
  solveNewtonRaphson,
  solveSecant,
  solveRegulaFalsi,
  solveGaussElimination,
  solveJacobi,
  solveGaussSeidel,
};

'use strict';

const solversService = require('./solvers.service');
const {
  validateBisection,
  validateNewtonRaphson,
  validateSecant,
  validateRegulaFalsi,
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

module.exports = {
  solveBisection,
  solveNewtonRaphson,
  solveSecant,
  solveRegulaFalsi,
};

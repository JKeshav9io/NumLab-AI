'use strict';

const solversService = require('./solvers.service');
const { validateBisection } = require('./solvers.validator');
const { sendSuccess } = require('../../common/utils');

function solveBisection(req, res) {
  const params = validateBisection(req.body);
  const result = solversService.runBisection(params, { requestId: req.id });

  return sendSuccess(res, result, req.id);
}

module.exports = {
  solveBisection,
};

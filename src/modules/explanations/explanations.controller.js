'use strict';

const { sendSuccess } = require('../../common/utils');
const { explainSolverResult } = require('./explanation.service');
const { validateExplainRequest } = require('./explanations.validator');

async function explain(req, res) {
  const params = validateExplainRequest(req.body);
  const result = await explainSolverResult(params);

  return sendSuccess(res, result, req.id);
}

module.exports = {
  explain,
};

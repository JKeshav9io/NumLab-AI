'use strict';

const logger = require('../../config/logger');
const { solveBisection } = require('./rootFinding/bisection.service');

function runBisection(params, context = {}) {
  const result = solveBisection(params);

  logger.info({
    requestId: context.requestId,
    method: 'root/bisection',
    status: result.status,
    executionTimeMs: result.executionTimeMs,
    iterationCount: result.iterations.length,
    warningCount: result.warnings.length,
  }, 'Solve completed');

  return result;
}

module.exports = {
  runBisection,
};

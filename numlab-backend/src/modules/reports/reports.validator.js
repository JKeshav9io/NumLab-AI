'use strict';

const Joi = require('joi');
const { validate } = require('../../common/validators');

const reportParamSchema = Joi.object({
  runId: Joi.string().guid().required(),
});

/**
 * Validates the runId path parameter for report generation.
 * @param {Object} params
 * @param {string} params.runId
 * @returns {Object} Validated params
 */
function validateReportParam(params) {
  return validate(reportParamSchema, params, {
    message: 'Invalid solver run ID parameter',
    useDetailsList: true,
    joiOptions: { convert: true },
  });
}

module.exports = {
  validateReportParam,
};

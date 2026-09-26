'use strict';

const Joi = require('joi');
const { AppError, errorCodes } = require('../../common/errors');

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
  const { value, error } = reportParamSchema.validate(params, {
    convert: true,
    stripUnknown: true,
  });

  if (error) {
    throw new AppError(
      'Invalid solver run ID parameter',
      400,
      errorCodes.VALIDATION_ERROR,
      { details: error.details.map((d) => d.message) }
    );
  }

  return value;
}

module.exports = {
  validateReportParam,
};

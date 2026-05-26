'use strict';

const Joi = require('joi');
const { AppError, errorCodes } = require('../../common/errors');

const bisectionSchema = Joi.object({
  equation: Joi.string().trim().max(500).required(),
  lowerBound: Joi.number().required(),
  upperBound: Joi.number().required(),
  tolerance: Joi.number().positive().max(1).default(0.0001),
  maxIterations: Joi.number().integer().min(1).max(1000).default(100),
  includeExplanation: Joi.boolean().default(true),
  includeGraphData: Joi.boolean().default(true),
}).custom((value, helpers) => {
  if (value.lowerBound >= value.upperBound) {
    return helpers.error('bounds.ordered');
  }

  return value;
}).messages({
  'bounds.ordered': 'lowerBound must be less than upperBound',
});

function validateBisection(body) {
  const { error, value } = bisectionSchema.validate(body, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    throw new AppError(
      'Validation failed',
      400,
      errorCodes.VALIDATION_ERROR,
      {
        fields: error.details.map((detail) => ({
          field: detail.path.join('.') || 'body',
          message: detail.message,
        })),
      }
    );
  }

  return value;
}

module.exports = {
  validateBisection,
};

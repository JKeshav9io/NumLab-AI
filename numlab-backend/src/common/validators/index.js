'use strict';

const { AppError, errorCodes } = require('../errors');

/**
 * Validates a payload against a Joi schema and maps errors to standard AppError.
 * @param {Object} schema - Joi schema
 * @param {Object} payload - Input payload to validate
 * @param {Object} [options] - Validation options
 * @param {string} [options.message] - Custom error message
 * @param {boolean} [options.useDetailsList] - Use string array details shape
 * @param {Object} [options.joiOptions] - Additional Joi validation options
 * @returns {Object} Validated and sanitized value
 */
function validate(schema, payload, options = {}) {
  const joiOptions = {
    abortEarly: false,
    stripUnknown: true,
    ...options.joiOptions,
  };

  const { error, value } = schema.validate(payload, joiOptions);

  if (error) {
    const details = options.useDetailsList
      ? { details: error.details.map((d) => d.message) }
      : {
          fields: error.details.map((detail) => ({
            field: detail.path.join('.') || 'body',
            message: detail.message,
          })),
        };

    throw new AppError(
      options.message || 'Validation failed',
      400,
      errorCodes.VALIDATION_ERROR,
      details
    );
  }

  return value;
}

module.exports = {
  validate,
};

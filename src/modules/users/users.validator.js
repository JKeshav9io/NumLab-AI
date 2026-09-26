'use strict';

const Joi = require('joi');
const { AppError, errorCodes } = require('../../common/errors');

const historyQuerySchema = Joi.object({
  limit: Joi.number().integer().min(1).max(100).default(20),
  offset: Joi.number().integer().min(0).default(0),
});

const runIdParamSchema = Joi.object({
  runId: Joi.string().guid({ version: ['uuidv4', 'uuidv5', 'uuidv1', 'uuidv3'] }).required(),
});

function validateHistoryQuery(query) {
  const { value, error } = historyQuerySchema.validate(query, {
    convert: true,
    stripUnknown: true,
  });

  if (error) {
    throw new AppError(
      'Invalid pagination query parameters',
      400,
      errorCodes.VALIDATION_ERROR,
      { details: error.details.map((d) => d.message) }
    );
  }

  return value;
}

function validateRunIdParam(params) {
  const { value, error } = runIdParamSchema.validate(params, {
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
  validateHistoryQuery,
  validateRunIdParam,
};

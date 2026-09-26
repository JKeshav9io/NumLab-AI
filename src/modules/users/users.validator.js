'use strict';

const Joi = require('joi');
const { validate } = require('../../common/validators');

const historyQuerySchema = Joi.object({
  limit: Joi.number().integer().min(1).max(100).default(20),
  offset: Joi.number().integer().min(0).default(0),
});

const runIdParamSchema = Joi.object({
  runId: Joi.string().guid({ version: ['uuidv4', 'uuidv5', 'uuidv1', 'uuidv3'] }).required(),
});

function validateHistoryQuery(query) {
  return validate(historyQuerySchema, query, {
    message: 'Invalid pagination query parameters',
    useDetailsList: true,
    joiOptions: { convert: true },
  });
}

function validateRunIdParam(params) {
  return validate(runIdParamSchema, params, {
    message: 'Invalid solver run ID parameter',
    useDetailsList: true,
    joiOptions: { convert: true },
  });
}

module.exports = {
  validateHistoryQuery,
  validateRunIdParam,
};

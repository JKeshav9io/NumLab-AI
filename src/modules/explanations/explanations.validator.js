'use strict';

const Joi = require('joi');
const { AppError, errorCodes } = require('../../common/errors');

const FOCUS_VALUES = ['summary', 'steps', 'warnings', 'lab-report'];
const MAX_EXPLAIN_ITERATIONS = 200;
const MAX_EXPLAIN_WARNINGS = 50;
const MAX_GRAPH_ARRAY_POINTS = 500;
const MAX_GRAPH_OBJECT_ARRAY_POINTS = 500;

const solverResultSchema = Joi.object({
  method: Joi.string().trim().required(),
  status: Joi.string().trim().required(),
  input: Joi.object().unknown(true).optional(),
  iterations: Joi.array().items(Joi.object().unknown(true)).max(MAX_EXPLAIN_ITERATIONS).optional(),
  finalAnswer: Joi.object().unknown(true).required(),
  graphData: Joi.any().optional(),
  warnings: Joi.array().items(Joi.string()).max(MAX_EXPLAIN_WARNINGS).optional(),
  executionTimeMs: Joi.number().min(0).optional(),
})
  .unknown(true)
  .custom(validateGraphDataSize)
  .messages({
    'graphData.tooLarge': `graphData contains too many points for AI explanation; max ${MAX_GRAPH_ARRAY_POINTS} points per graph array`,
  })
  .required();

const explainSchema = Joi.object({
  solverResult: solverResultSchema,
  focus: Joi.string().valid(...FOCUS_VALUES).default('steps'),
  includeGraphSummary: Joi.boolean().default(false),
});

function validateExplainRequest(body) {
  const { error, value } = explainSchema.validate(body, {
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

function validateGraphDataSize(value, helpers) {
  const { graphData } = value;

  if (Array.isArray(graphData) && graphData.length > MAX_GRAPH_ARRAY_POINTS) {
    return helpers.error('graphData.tooLarge');
  }

  if (graphData && typeof graphData === 'object' && !Array.isArray(graphData)) {
    const tooLargeKey = Object.entries(graphData).find(([_key, nestedValue]) => (
      Array.isArray(nestedValue) && nestedValue.length > MAX_GRAPH_OBJECT_ARRAY_POINTS
    ));

    if (tooLargeKey) {
      return helpers.error('graphData.tooLarge');
    }
  }

  return value;
}

module.exports = {
  FOCUS_VALUES,
  MAX_EXPLAIN_ITERATIONS,
  MAX_EXPLAIN_WARNINGS,
  MAX_GRAPH_ARRAY_POINTS,
  MAX_GRAPH_OBJECT_ARRAY_POINTS,
  validateExplainRequest,
};

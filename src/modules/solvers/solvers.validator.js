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

const newtonRaphsonSchema = Joi.object({
  equation: Joi.string().trim().max(500).required(),
  derivativeEquation: Joi.string().trim().max(500).optional(),
  initialGuess: Joi.number().required(),
  tolerance: Joi.number().positive().max(1).default(0.0001),
  maxIterations: Joi.number().integer().min(1).max(1000).default(100),
  includeExplanation: Joi.boolean().default(true),
  includeGraphData: Joi.boolean().default(true),
});

const secantSchema = Joi.object({
  equation: Joi.string().trim().max(500).required(),
  firstGuess: Joi.number().required(),
  secondGuess: Joi.number().required(),
  tolerance: Joi.number().positive().max(1).default(0.0001),
  maxIterations: Joi.number().integer().min(1).max(1000).default(100),
  includeExplanation: Joi.boolean().default(true),
  includeGraphData: Joi.boolean().default(true),
}).custom((value, helpers) => {
  if (value.firstGuess === value.secondGuess) {
    return helpers.error('guesses.distinct');
  }

  return value;
}).messages({
  'guesses.distinct': 'firstGuess and secondGuess must be different',
});

const regulaFalsiSchema = bisectionSchema;

const matrixSchema = Joi.array()
  .items(Joi.array().items(Joi.number().required()).min(1).required())
  .min(1)
  .required();

const constantsSchema = Joi.array()
  .items(Joi.number().required())
  .min(1)
  .required();

const gaussEliminationSchema = Joi.object({
  matrix: matrixSchema,
  constants: constantsSchema,
  includeExplanation: Joi.boolean().default(true),
});

const iterativeLinearSchema = Joi.object({
  matrix: matrixSchema,
  constants: constantsSchema,
  initialGuess: Joi.array().items(Joi.number().required()).min(1).optional(),
  tolerance: Joi.number().positive().max(1).default(0.0001),
  maxIterations: Joi.number().integer().min(1).max(10000).default(100),
  includeExplanation: Joi.boolean().default(true),
});

function validateBisection(body) {
  return validateWithSchema(bisectionSchema, body);
}

function validateNewtonRaphson(body) {
  return validateWithSchema(newtonRaphsonSchema, body);
}

function validateSecant(body) {
  return validateWithSchema(secantSchema, body);
}

function validateRegulaFalsi(body) {
  return validateWithSchema(regulaFalsiSchema, body);
}

function validateGaussElimination(body) {
  return validateLinearSystem(gaussEliminationSchema, body, { requireInitialGuess: false });
}

function validateJacobi(body) {
  return validateLinearSystem(iterativeLinearSchema, body, { requireInitialGuess: false });
}

function validateGaussSeidel(body) {
  return validateLinearSystem(iterativeLinearSchema, body, { requireInitialGuess: false });
}

function validateWithSchema(schema, body) {
  const { error, value } = schema.validate(body, {
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

function validateLinearSystem(schema, body) {
  const value = validateWithSchema(schema, body);
  const size = value.matrix.length;
  const dimensionErrors = [];

  value.matrix.forEach((row, rowIndex) => {
    if (row.length !== size) {
      dimensionErrors.push({
        field: `matrix.${rowIndex}`,
        message: `matrix row ${rowIndex + 1} must contain exactly ${size} values`,
      });
    }
  });

  if (value.constants.length !== size) {
    dimensionErrors.push({
      field: 'constants',
      message: `constants must contain exactly ${size} values`,
    });
  }

  if (value.initialGuess && value.initialGuess.length !== size) {
    dimensionErrors.push({
      field: 'initialGuess',
      message: `initialGuess must contain exactly ${size} values`,
    });
  }

  if (dimensionErrors.length > 0) {
    throw new AppError(
      'Validation failed',
      400,
      errorCodes.VALIDATION_ERROR,
      { fields: dimensionErrors }
    );
  }

  return value;
}

module.exports = {
  validateBisection,
  validateNewtonRaphson,
  validateSecant,
  validateRegulaFalsi,
  validateGaussElimination,
  validateJacobi,
  validateGaussSeidel,
};

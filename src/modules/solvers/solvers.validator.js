'use strict';

const Joi = require('joi');
const { AppError, errorCodes } = require('../../common/errors');

const INTERPOLATION_NEAR_ZERO_THRESHOLD = 1e-12;

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

const interpolationPointSchema = Joi.object({
  x: Joi.number().required(),
  y: Joi.number().required(),
}).required();

const interpolationSchema = Joi.object({
  points: Joi.array().items(interpolationPointSchema).min(2).max(100).required(),
  targetX: Joi.number().required(),
  includeExplanation: Joi.boolean().default(true),
  includeGraphData: Joi.boolean().default(true),
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

function validateLagrangeInterpolation(body) {
  return validateInterpolation(interpolationSchema, body, {
    minPoints: 2,
    methodName: 'Lagrange interpolation',
  });
}

function validateNewtonDividedDifference(body) {
  return validateInterpolation(interpolationSchema, body, {
    minPoints: 2,
    methodName: 'Newton divided difference',
  });
}

function validateNaturalCubicSpline(body) {
  return validateInterpolation(interpolationSchema, body, {
    minPoints: 3,
    methodName: 'Natural cubic spline',
    validateSpacing: true,
  });
}

function validateQuadraticInterpolation(body) {
  return validateInterpolation(interpolationSchema, body, {
    minPoints: 3,
    methodName: 'Quadratic interpolation',
  });
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

function validateInterpolation(schema, body, options) {
  const value = validateWithSchema(schema, body);
  const errors = [];

  if (value.points.length < options.minPoints) {
    errors.push({
      field: 'points',
      message: `${options.methodName} requires at least ${options.minPoints} points`,
    });
  }

  if (!Number.isFinite(value.targetX)) {
    errors.push({
      field: 'targetX',
      message: 'targetX must be a finite number',
    });
  }

  const seenXValues = new Set();

  value.points.forEach((point, index) => {
    if (!Number.isFinite(point.x)) {
      errors.push({
        field: `points.${index}.x`,
        message: 'x must be a finite number',
      });
    }

    if (!Number.isFinite(point.y)) {
      errors.push({
        field: `points.${index}.y`,
        message: 'y must be a finite number',
      });
    }

    if (seenXValues.has(point.x)) {
      errors.push({
        field: `points.${index}.x`,
        message: 'x values must be unique',
      });
    }

    seenXValues.add(point.x);
  });

  if (options.validateSpacing) {
    const sortedPoints = value.points.slice().sort((a, b) => a.x - b.x);

    for (let index = 0; index < sortedPoints.length - 1; index++) {
      const intervalWidth = sortedPoints[index + 1].x - sortedPoints[index].x;

      if (Math.abs(intervalWidth) < INTERPOLATION_NEAR_ZERO_THRESHOLD) {
        errors.push({
          field: 'points',
          message: 'natural cubic spline interval width is too close to zero',
        });
        break;
      }
    }
  }

  if (errors.length > 0) {
    throw new AppError(
      'Validation failed',
      400,
      errorCodes.VALIDATION_ERROR,
      { fields: errors }
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
  validateLagrangeInterpolation,
  validateNewtonDividedDifference,
  validateNaturalCubicSpline,
  validateQuadraticInterpolation,
};

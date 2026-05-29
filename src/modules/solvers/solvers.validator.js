'use strict';

const Joi = require('joi');
const { AppError, errorCodes } = require('../../common/errors');
const {
  CENTRAL_DIFFERENCE_VARIANTS,
  EQUAL_SPACING_TOLERANCE,
  INTERPOLATION_NEAR_ZERO_THRESHOLD,
  MAX_INTERPOLATION_POINTS,
} = require('./interpolation/interpolation.constants');

const ODE_STEP_MULTIPLE_TOLERANCE = 1e-10;

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
  points: Joi.array().items(interpolationPointSchema).min(2).max(MAX_INTERPOLATION_POINTS).required(),
  targetX: Joi.number().required(),
  includeExplanation: Joi.boolean().default(true),
  includeGraphData: Joi.boolean().default(true),
});

const centralDifferenceSchema = interpolationSchema.keys({
  variant: Joi.string().valid(...CENTRAL_DIFFERENCE_VARIANTS).required(),
});

const odeSchema = Joi.object({
  equation: Joi.string().trim().max(500).required(),
  x0: Joi.number().required(),
  y0: Joi.number().required(),
  h: Joi.number().positive().required(),
  xn: Joi.number().optional(),
  steps: Joi.number().integer().min(1).max(10000).optional(),
  includeExplanation: Joi.boolean().default(true),
  includeGraphData: Joi.boolean().default(true),
});

const integrationBaseSchema = Joi.object({
  equation: Joi.string().trim().max(500).required(),
  lowerBound: Joi.number().required(),
  upperBound: Joi.number().required(),
  exactValue: Joi.number().optional(),
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

const trapezoidalSchema = integrationBaseSchema.keys({
  subintervals: Joi.number().integer().min(1).max(10000).required(),
});

const simpsonOneThirdSchema = integrationBaseSchema.keys({
  subintervals: Joi.number().integer().min(2).max(10000).required(),
}).custom((value, helpers) => {
  if (value.subintervals % 2 !== 0) {
    return helpers.error('subintervals.even');
  }

  return value;
}).messages({
  'subintervals.even': "subintervals must be even for Simpson's 1/3 Rule",
});

const simpsonThreeEighthSchema = integrationBaseSchema.keys({
  subintervals: Joi.number().integer().min(3).max(9999).required(),
}).custom((value, helpers) => {
  if (value.subintervals % 3 !== 0) {
    return helpers.error('subintervals.divisibleByThree');
  }

  return value;
}).messages({
  'subintervals.divisibleByThree': "subintervals must be divisible by 3 for Simpson's 3/8 Rule",
});

const gaussLegendreSchema = integrationBaseSchema.keys({
  points: Joi.number().integer().valid(2, 3, 4, 5).required(),
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

function validateNewtonForwardInterpolation(body) {
  return validateInterpolation(interpolationSchema, body, {
    minPoints: 2,
    methodName: 'Newton forward interpolation',
    requireEqualSpacing: true,
  });
}

function validateNewtonBackwardInterpolation(body) {
  return validateInterpolation(interpolationSchema, body, {
    minPoints: 2,
    methodName: 'Newton backward interpolation',
    requireEqualSpacing: true,
  });
}

function validateCentralDifferenceInterpolation(body) {
  return validateInterpolation(centralDifferenceSchema, body, {
    minPoints: 3,
    methodName: 'Central difference interpolation',
    requireEqualSpacing: true,
    validateBesselShape: true,
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

function validateEulerODE(body) {
  return validateODE(odeSchema, body, {
    methodName: 'Euler Method',
  });
}

function validateHeunODE(body) {
  return validateODE(odeSchema, body, {
    methodName: 'Heun Method',
  });
}

function validateRK4ODE(body) {
  return validateODE(odeSchema, body, {
    methodName: 'RK4 Method',
  });
}

function validateMilneODE(body) {
  return validateODE(odeSchema, body, {
    methodName: 'Milne Predictor-Corrector Method',
    minSteps: 4,
  });
}

function validateTrapezoidalIntegration(body) {
  return validateWithSchema(trapezoidalSchema, body);
}

function validateSimpsonOneThirdIntegration(body) {
  return validateWithSchema(simpsonOneThirdSchema, body);
}

function validateSimpsonThreeEighthIntegration(body) {
  return validateWithSchema(simpsonThreeEighthSchema, body);
}

function validateGaussLegendreIntegration(body) {
  return validateWithSchema(gaussLegendreSchema, body);
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

function validateODE(schema, body, options) {
  const value = validateWithSchema(schema, body);
  const errors = [];
  const hasXn = value.xn !== undefined;
  const hasSteps = value.steps !== undefined;

  if (!hasXn && !hasSteps) {
    errors.push({
      field: 'xn',
      message: 'either xn or steps is required',
    });
  }

  if (hasXn && hasSteps) {
    errors.push({
      field: 'body',
      message: 'provide either xn or steps, not both',
    });
  }

  if (hasXn && value.xn <= value.x0) {
    errors.push({
      field: 'xn',
      message: 'xn must be greater than x0 for positive h',
    });
  }

  if (hasXn && value.xn > value.x0 && !isWholeStepMultiple(value.x0, value.xn, value.h)) {
    errors.push({
      field: 'xn',
      message: 'xn - x0 must be an exact positive multiple of h, or provide steps instead',
    });
  }

  const resolvedSteps = hasSteps ? value.steps : Math.round((value.xn - value.x0) / value.h);

  if (options.minSteps && resolvedSteps < options.minSteps) {
    errors.push({
      field: hasSteps ? 'steps' : 'xn',
      message: `${options.methodName} requires at least ${options.minSteps} steps`,
    });
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

  if (options.requireEqualSpacing) {
    const sortedPoints = value.points.slice().sort((a, b) => a.x - b.x);
    const expectedSpacing = sortedPoints[1].x - sortedPoints[0].x;

    for (let index = 1; index < sortedPoints.length - 1; index++) {
      const actualSpacing = sortedPoints[index + 1].x - sortedPoints[index].x;

      if (Math.abs(actualSpacing - expectedSpacing) > EQUAL_SPACING_TOLERANCE) {
        errors.push({
          field: 'points',
          message: 'x values must be equally spaced for finite-difference interpolation',
        });
        break;
      }
    }
  }

  if (options.validateBesselShape && value.variant === 'bessel' && value.points.length < 4) {
    errors.push({
      field: 'points',
      message: 'Bessel interpolation requires at least 4 equally spaced points',
    });
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

function isWholeStepMultiple(x0, xn, h) {
  const rawSteps = (xn - x0) / h;
  return rawSteps > 0 && Math.abs(rawSteps - Math.round(rawSteps)) <= ODE_STEP_MULTIPLE_TOLERANCE;
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
  validateNewtonForwardInterpolation,
  validateNewtonBackwardInterpolation,
  validateCentralDifferenceInterpolation,
  validateNaturalCubicSpline,
  validateQuadraticInterpolation,
  validateEulerODE,
  validateHeunODE,
  validateRK4ODE,
  validateMilneODE,
  validateTrapezoidalIntegration,
  validateSimpsonOneThirdIntegration,
  validateSimpsonThreeEighthIntegration,
  validateGaussLegendreIntegration,
};

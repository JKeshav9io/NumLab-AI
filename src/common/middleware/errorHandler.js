'use strict';

const logger = require('../../config/logger');
const { AppError, errorCodes } = require('../errors');

module.exports = function errorHandler(err, req, res, _next) {
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({
      success: false,
      error: {
        code: errorCodes.INVALID_JSON,
        message: 'Request body contains invalid JSON',
      },
    });
  }

  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error({ err, requestId: req.id, details: err.details }, 'Server error encountered');
    }

    const error = {
      code: err.code,
      message: err.message,
    };

    if (err.details) {
      // Redact internal database error messages and stack details from client-facing responses
      const sanitizedDetails = { ...err.details };
      delete sanitizedDetails.originalError;

      if (Object.keys(sanitizedDetails).length > 0) {
        error.details = sanitizedDetails;
      }
    }

    return res.status(err.statusCode).json({
      success: false,
      error,
    });
  }

  logger.error({ err, requestId: req.id }, 'Unhandled error');

  return res.status(500).json({
    success: false,
    error: {
      code: errorCodes.INTERNAL_ERROR,
      message: 'An unexpected error occurred',
    },
  });
};

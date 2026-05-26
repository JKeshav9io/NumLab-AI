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
    const error = {
      code: err.code,
      message: err.message,
    };

    if (err.details) {
      error.details = err.details;
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

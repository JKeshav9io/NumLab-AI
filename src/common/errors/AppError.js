'use strict';

class AppError extends Error {
  constructor(message, statusCode, code, details = null) {
    super(message);

    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;

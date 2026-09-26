'use strict';

const { verifyToken } = require('../../modules/auth/token');
const { AppError, errorCodes } = require('../errors');

/**
 * Express middleware to authenticate requests via Bearer JWT token.
 * Attaches decoded user identity `req.user = { id }` to the request.
 */
function authenticate(req, _res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(
      new AppError(
        'Authentication required. Please provide a Bearer access token.',
        401,
        errorCodes.UNAUTHORIZED
      )
    );
  }

  const token = authHeader.substring(7).trim();
  if (!token) {
    return next(
      new AppError(
        'Authentication token is empty',
        401,
        errorCodes.UNAUTHORIZED
      )
    );
  }

  try {
    const payload = verifyToken(token, 'access');
    req.user = {
      id: payload.sub,
    };

    return next();
  } catch (error) {
    return next(error);
  }
}

module.exports = authenticate;

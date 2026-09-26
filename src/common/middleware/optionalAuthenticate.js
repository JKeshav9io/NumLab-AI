'use strict';

const { verifyToken } = require('../../modules/auth/token');

/**
 * Express middleware for optional authentication.
 *
 * Distinction vs authenticate.js:
 * - `authenticate.js` strictly requires a valid Bearer JWT token and throws 401 UNAUTHORIZED
 *   if the token is missing, malformed, expired, or invalid.
 * - `optionalAuthenticate.js` is non-blocking and never rejects a request. If a valid Bearer token
 *   is present, it attaches `req.user = { id: payload.sub }`. If no Authorization header is provided,
 *   or if the token is malformed, expired, or invalid, it sets `req.user = null` and proceeds.
 *   This allows public endpoints (such as /api/v1/solve/*) to attribute activity to authenticated
 *   users when available, while remaining 100% accessible and functional for anonymous users.
 */
function optionalAuthenticate(req, _res, next) {
  req.user = null;

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }

  const token = authHeader.substring(7).trim();
  if (!token) {
    return next();
  }

  try {
    const payload = verifyToken(token, 'access');
    req.user = {
      id: payload.sub,
    };
  } catch (_err) {
    // Gracefully ignore expired or invalid tokens for optional auth routes
    req.user = null;
  }

  return next();
}

module.exports = optionalAuthenticate;

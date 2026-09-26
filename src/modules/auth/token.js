'use strict';

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const { AppError, errorCodes } = require('../../common/errors');

const ACCESS_TOKEN_EXPIRES_IN = '15m'; // 15 minutes

/**
 * Generates a short-lived access token (15 minutes).
 * @param {string} userId - User UUID
 * @returns {string} Signed JWT access token
 */
function generateAccessToken(userId) {
  return jwt.sign(
    {
      sub: userId,
      type: 'access',
    },
    env.JWT_SECRET,
    {
      expiresIn: ACCESS_TOKEN_EXPIRES_IN,
      issuer: 'numlab-backend',
    }
  );
}

/**
 * Generates a long-lived refresh token (e.g. 7 days).
 * @param {string} userId - User UUID
 * @returns {string} Signed JWT refresh token
 */
function generateRefreshToken(userId) {
  return jwt.sign(
    {
      sub: userId,
      type: 'refresh',
    },
    env.JWT_SECRET,
    {
      expiresIn: env.JWT_EXPIRES_IN,
      issuer: 'numlab-backend',
    }
  );
}

/**
 * Verifies a JWT token and validates its expected token type.
 * Explicitly differentiates between expired tokens and malformed/tampered signatures.
 * @param {string} token
 * @param {'access'|'refresh'} [expectedType='access']
 * @returns {Object} Decoded token payload
 */
function verifyToken(token, expectedType = 'access') {
  if (!token) {
    throw new AppError(
      'Authentication token is required',
      401,
      errorCodes.UNAUTHORIZED
    );
  }

  try {
    const decoded = jwt.verify(token, env.JWT_SECRET, {
      issuer: 'numlab-backend',
    });

    if (decoded.type !== expectedType) {
      throw new AppError(
        `Invalid token type: expected ${expectedType} token`,
        401,
        errorCodes.INVALID_TOKEN
      );
    }

    return decoded;
  } catch (err) {
    if (err instanceof AppError) {
      throw err;
    }

    if (err.name === 'TokenExpiredError') {
      throw new AppError(
        'Authentication token has expired',
        401,
        errorCodes.TOKEN_EXPIRED,
        { expiredAt: err.expiredAt }
      );
    }

    if (err.name === 'JsonWebTokenError') {
      throw new AppError(
        'Invalid authentication token signature or format',
        401,
        errorCodes.INVALID_TOKEN
      );
    }

    throw new AppError(
      'Token verification failed',
      401,
      errorCodes.UNAUTHORIZED
    );
  }
}

/**
 * Generates a SHA-256 hash of a token for server-side database storage.
 * Storing raw tokens in the DB is dangerous (DB leak = session hijacking).
 * Storing SHA-256 hashes allows exact lookup without exposing usable tokens.
 * @param {string} token
 * @returns {string} 64-character hex hash
 */
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

module.exports = {
  ACCESS_TOKEN_EXPIRES_IN,
  generateAccessToken,
  generateRefreshToken,
  verifyToken,
  hashToken,
};

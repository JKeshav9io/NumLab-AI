'use strict';

const { prisma } = require('../../db');
const userRepository = require('../../db/repositories/userRepository');
const refreshTokenRepository = require('../../db/repositories/refreshTokenRepository');
const { hashPassword, verifyPassword } = require('./password');
const {
  generateAccessToken,
  generateRefreshToken,
  verifyToken,
  hashToken,
} = require('./token');
const { AppError, errorCodes } = require('../../common/errors');
const logger = require('../../config/logger');

// 7 days in milliseconds for refresh token expiration calculation
const REFRESH_TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const ACCESS_TOKEN_EXPIRY_SECONDS = 15 * 60; // 900 seconds (15 min)

/**
 * Registers a new user and issues their initial token pair.
 * @param {string} email
 * @param {string} password
 * @returns {Promise<{ user: Object, tokens: Object }>}
 */
async function register(email, password) {
  const normalizedEmail = email.toLowerCase().trim();

  // Check if user already exists
  const existingUser = await userRepository.findByEmail(normalizedEmail);
  if (existingUser) {
    throw new AppError(
      'A user with this email address already exists',
      409,
      errorCodes.CONFLICT,
      { field: 'email' }
    );
  }

  // Hash password with bcrypt cost factor 12
  const passwordHash = await hashPassword(password);

  // Persist user record
  const user = await userRepository.createUser({
    email: normalizedEmail,
    passwordHash,
  });

  // Issue token pair
  const tokens = await issueTokenPair(user.id);

  logger.info({ userId: user.id }, 'User registered successfully');

  return {
    user: sanitizeUser(user),
    tokens,
  };
}

/**
 * Authenticates a user by email and password and issues a new token pair.
 * @param {string} email
 * @param {string} password
 * @returns {Promise<{ user: Object, tokens: Object }>}
 */
async function login(email, password) {
  const normalizedEmail = email.toLowerCase().trim();
  const user = await userRepository.findByEmail(normalizedEmail);

  // Security note: We use a generic message to prevent account enumeration attacks.
  if (!user) {
    throw new AppError(
      'Invalid email or password',
      401,
      errorCodes.INVALID_CREDENTIALS
    );
  }

  const isPasswordValid = await verifyPassword(password, user.passwordHash);
  if (!isPasswordValid) {
    throw new AppError(
      'Invalid email or password',
      401,
      errorCodes.INVALID_CREDENTIALS
    );
  }

  // Update last login timestamp asynchronously
  await prisma.user.update({
    where: { id: user.id },
    data: { lastLoginAt: new Date() },
  });

  const tokens = await issueTokenPair(user.id);

  logger.info({ userId: user.id }, 'User logged in successfully');

  return {
    user: sanitizeUser(user),
    tokens,
  };
}

/**
 * Validates a refresh token, performs single-use rotation, and issues a fresh token pair.
 * @param {string} rawRefreshToken
 * @returns {Promise<{ tokens: Object }>}
 */
async function refresh(rawRefreshToken) {
  // Verify token format and signature
  const decoded = verifyToken(rawRefreshToken, 'refresh');
  const tokenHash = hashToken(rawRefreshToken);

  // Look up stored active token in database
  const storedToken = await refreshTokenRepository.findByTokenHash(tokenHash);
  if (!storedToken) {
    throw new AppError(
      'Refresh token is invalid or has been revoked',
      401,
      errorCodes.TOKEN_REVOKED
    );
  }

  // REFRESH TOKEN ROTATION:
  // Atomically invalidate the old refresh token. If 0 rows were updated,
  // a concurrent request or replay already consumed this token.
  const revokedCount = await refreshTokenRepository.revokeToken(tokenHash);
  if (!revokedCount || revokedCount === 0) {
    throw new AppError(
      'Refresh token is invalid or has been revoked',
      401,
      errorCodes.TOKEN_REVOKED
    );
  }

  // Issue brand new token pair
  const tokens = await issueTokenPair(decoded.sub);

  logger.info({ userId: decoded.sub }, 'Refresh token rotated successfully');

  return {
    tokens,
  };
}

/**
 * Revokes a specific refresh token (logging out current session).
 * @param {string} rawRefreshToken
 * @returns {Promise<{ message: string }>}
 */
async function logout(rawRefreshToken) {
  if (rawRefreshToken) {
    const tokenHash = hashToken(rawRefreshToken);
    await refreshTokenRepository.revokeToken(tokenHash);
  }

  return { message: 'Logged out successfully' };
}

/**
 * Revokes all refresh tokens for a user across all devices.
 * @param {string} userId
 * @returns {Promise<{ message: string }>}
 */
async function logoutAllDevices(userId) {
  await refreshTokenRepository.revokeAllForUser(userId);
  logger.info({ userId }, 'All refresh tokens revoked for user');

  return { message: 'Logged out of all devices successfully' };
}

/**
 * Internal helper to generate and store a new token pair.
 * @param {string} userId
 * @returns {Promise<{ accessToken: string, refreshToken: string, expiresIn: number }>}
 */
async function issueTokenPair(userId) {
  const accessToken = generateAccessToken(userId);
  const refreshToken = generateRefreshToken(userId);
  const tokenHash = hashToken(refreshToken);
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);

  // Persist refresh token hash in DB
  await refreshTokenRepository.create({
    userId,
    tokenHash,
    expiresAt,
  });

  return {
    accessToken,
    refreshToken,
    expiresIn: ACCESS_TOKEN_EXPIRY_SECONDS,
  };
}

/**
 * Strips passwordHash and internal fields before returning user data.
 * @param {Object} user
 * @returns {Object}
 */
function sanitizeUser(user) {
  return {
    id: user.id,
    email: user.email,
    emailVerified: user.emailVerified,
    createdAt: user.createdAt,
    lastLoginAt: user.lastLoginAt,
  };
}

module.exports = {
  register,
  login,
  refresh,
  logout,
  logoutAllDevices,
  sanitizeUser,
};

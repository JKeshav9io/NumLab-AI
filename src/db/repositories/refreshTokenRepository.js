'use strict';

const { prisma } = require('../index');
const logger = require('../../config/logger');
const { AppError, errorCodes } = require('../../common/errors');

/**
 * Stores a hashed refresh token in the database.
 * @param {Object} data
 * @param {string} data.userId - User UUID
 * @param {string} data.tokenHash - SHA-256 hash of the refresh token
 * @param {Date} data.expiresAt - Expiration timestamp
 * @returns {Promise<Object>} Created RefreshToken record
 */
async function create(data) {
  try {
    return await prisma.refreshToken.create({
      data: {
        userId: data.userId,
        tokenHash: data.tokenHash,
        expiresAt: data.expiresAt,
      },
    });
  } catch (error) {
    logger.error({ err: error, userId: data.userId }, 'Failed to persist refresh token in database');
    throw new AppError(
      'Failed to persist refresh token',
      500,
      errorCodes.DATABASE_ERROR
    );
  }
}

/**
 * Finds an active, unrevoked, non-expired refresh token by its SHA-256 hash.
 * Includes user record (excluding deleted users).
 * @param {string} tokenHash
 * @returns {Promise<Object|null>}
 */
async function findByTokenHash(tokenHash) {
  try {
    const now = new Date();

    return await prisma.refreshToken.findFirst({
      where: {
        tokenHash,
        revokedAt: null,
        expiresAt: { gt: now },
        user: {
          deletedAt: null,
        },
      },
      include: {
        user: true,
      },
    });
  } catch (error) {
    logger.error({ err: error }, 'Failed to query refresh token by hash in database');
    throw new AppError(
      'Failed to query refresh token by hash',
      500,
      errorCodes.DATABASE_ERROR
    );
  }
}

/**
 * Revokes a single refresh token by its SHA-256 hash.
 * @param {string} tokenHash
 * @returns {Promise<number>} Count of revoked tokens (0 or 1)
 */
async function revokeToken(tokenHash) {
  try {
    const result = await prisma.refreshToken.updateMany({
      where: {
        tokenHash,
        revokedAt: null,
      },
      data: {
        revokedAt: new Date(),
      },
    });

    return result.count;
  } catch (error) {
    logger.error({ err: error }, 'Failed to revoke refresh token in database');
    throw new AppError(
      'Failed to revoke refresh token',
      500,
      errorCodes.DATABASE_ERROR
    );
  }
}

/**
 * Revokes all active refresh tokens for a user (e.g. "log out all devices").
 * @param {string} userId
 * @returns {Promise<number>} Count of revoked tokens
 */
async function revokeAllForUser(userId) {
  try {
    const result = await prisma.refreshToken.updateMany({
      where: {
        userId,
        revokedAt: null,
      },
      data: {
        revokedAt: new Date(),
      },
    });

    return result.count;
  } catch (error) {
    logger.error({ err: error, userId }, 'Failed to revoke all user refresh tokens in database');
    throw new AppError(
      'Failed to revoke all user refresh tokens',
      500,
      errorCodes.DATABASE_ERROR
    );
  }
}

module.exports = {
  create,
  findByTokenHash,
  revokeToken,
  revokeAllForUser,
};

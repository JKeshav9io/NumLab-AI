'use strict';

const { prisma } = require('../index');
const { AppError, errorCodes } = require('../../common/errors');

/**
 * Creates a new user record.
 * @param {Object} data
 * @param {string} data.email
 * @param {string} data.passwordHash
 * @returns {Promise<Object>} Created user object (excluding sensitive internals)
 */
async function createUser(data) {
  try {
    const user = await prisma.user.create({
      data: {
        email: data.email.toLowerCase().trim(),
        passwordHash: data.passwordHash,
      },
    });

    return user;
  } catch (error) {
    // Unique constraint violation in Prisma (P2002)
    if (error.code === 'P2002') {
      throw new AppError(
        'A user with this email address already exists',
        409,
        errorCodes.CONFLICT,
        { field: 'email' }
      );
    }

    throw new AppError(
      'Failed to create user record',
      500,
      errorCodes.DATABASE_ERROR,
      { originalError: error.message }
    );
  }
}

/**
 * Finds an active (non-soft-deleted) user by email.
 * @param {string} email
 * @returns {Promise<Object|null>}
 */
async function findByEmail(email) {
  try {
    return await prisma.user.findFirst({
      where: {
        email: email.toLowerCase().trim(),
        deletedAt: null,
      },
    });
  } catch (error) {
    throw new AppError(
      'Failed to query user by email',
      500,
      errorCodes.DATABASE_ERROR,
      { originalError: error.message }
    );
  }
}

/**
 * Finds an active (non-soft-deleted) user by UUID.
 * @param {string} id
 * @returns {Promise<Object|null>}
 */
async function findById(id) {
  try {
    return await prisma.user.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });
  } catch (error) {
    throw new AppError(
      'Failed to query user by id',
      500,
      errorCodes.DATABASE_ERROR,
      { id, originalError: error.message }
    );
  }
}

/**
 * Performs a soft-delete on a user by setting deletedAt timestamp.
 * @param {string} id
 * @returns {Promise<Object>} Updated user record
 */
async function softDeleteUser(id) {
  try {
    return await prisma.user.update({
      where: { id },
      data: {
        deletedAt: new Date(),
      },
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new AppError(
        'User not found or already deleted',
        404,
        errorCodes.NOT_FOUND,
        { id }
      );
    }

    throw new AppError(
      'Failed to soft-delete user record',
      500,
      errorCodes.DATABASE_ERROR,
      { id, originalError: error.message }
    );
  }
}

module.exports = {
  createUser,
  findByEmail,
  findById,
  softDeleteUser,
};

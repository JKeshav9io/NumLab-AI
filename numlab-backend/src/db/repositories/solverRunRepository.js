'use strict';

const { prisma } = require('../index');
const logger = require('../../config/logger');
const { AppError, errorCodes } = require('../../common/errors');

/**
 * Persists a new deterministic solver run result.
 * @param {Object} data
 * @param {string|null} [data.userId] - Nullable for anonymous solves
 * @param {string} data.method - Method route key (e.g. 'root/bisection')
 * @param {Object} data.inputPayload - Solver input parameters
 * @param {Object} data.outputPayload - Structured solver results & graph data
 * @returns {Promise<Object>} Created SolverRun record
 */
async function create(data) {
  try {
    const run = await prisma.solverRun.create({
      data: {
        userId: data.userId || null,
        method: data.method,
        inputPayload: data.inputPayload,
        outputPayload: data.outputPayload,
      },
    });

    return run;
  } catch (error) {
    logger.error({ err: error, method: data.method }, 'Failed to persist solver run in database');
    throw new AppError(
      'Failed to persist solver run',
      500,
      errorCodes.DATABASE_ERROR
    );
  }
}

/**
 * Retrieves paginated solver history for a user, ordered newest first.
 * @param {string} userId
 * @param {Object} [options]
 * @param {number} [options.limit=20]
 * @param {number} [options.offset=0]
 * @returns {Promise<{ runs: Array<Object>, total: number }>}
 */
async function findByUserId(userId, { limit = 20, offset = 0 } = {}) {
  try {
    const [runs, total] = await Promise.all([
      prisma.solverRun.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: Math.min(Math.max(1, limit), 100),
        skip: Math.max(0, offset),
      }),
      prisma.solverRun.count({
        where: { userId },
      }),
    ]);

    return { runs, total };
  } catch (error) {
    logger.error({ err: error, userId }, 'Failed to query solver runs for user in database');
    throw new AppError(
      'Failed to query solver runs for user',
      500,
      errorCodes.DATABASE_ERROR
    );
  }
}

/**
 * Retrieves a single solver run by UUID, including attached AI explanations.
 * @param {string} id
 * @returns {Promise<Object|null>}
 */
async function findById(id) {
  try {
    return await prisma.solverRun.findUnique({
      where: { id },
      include: {
        aiExplanations: {
          orderBy: { createdAt: 'asc' },
        },
      },
    });
  } catch (error) {
    logger.error({ err: error, id }, 'Failed to query solver run by id in database');
    throw new AppError(
      'Failed to query solver run by id',
      500,
      errorCodes.DATABASE_ERROR
    );
  }
}

module.exports = {
  create,
  findByUserId,
  findById,
};

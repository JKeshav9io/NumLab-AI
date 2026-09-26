'use strict';

const { prisma } = require('../index');
const logger = require('../../config/logger');
const { AppError, errorCodes } = require('../../common/errors');

/**
 * Persists an AI pedagogical explanation linked to a SolverRun.
 * @param {Object} data
 * @param {string} data.solverRunId
 * @param {string} [data.focusMode='steps']
 * @param {string} data.promptHash - Unique hash of the solver payload & focus mode
 * @param {string} data.responseText - Generated markdown explanation text
 * @param {Date|null} [data.expiresAt] - Optional TTL expiration date
 * @returns {Promise<Object>} Created AiExplanation record
 */
async function create(data) {
  try {
    const explanation = await prisma.aiExplanation.create({
      data: {
        solverRunId: data.solverRunId || null,
        userId: data.userId || null,
        focusMode: data.focusMode || 'steps',
        promptHash: data.promptHash,
        responseText: data.responseText,
        expiresAt: data.expiresAt || null,
      },
    });

    return explanation;
  } catch (error) {
    logger.error({ err: error, solverRunId: data.solverRunId }, 'Failed to persist AI explanation in database');
    throw new AppError(
      'Failed to persist AI explanation',
      500,
      errorCodes.DATABASE_ERROR
    );
  }
}

/**
 * Looks up a cached AI explanation by its promptHash.
 * Only returns non-expired cache entries.
 * @param {string} promptHash
 * @returns {Promise<Object|null>}
 */
async function findByPromptHash(promptHash) {
  try {
    const now = new Date();

    return await prisma.aiExplanation.findFirst({
      where: {
        promptHash,
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: now } },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
  } catch (error) {
    logger.error({ err: error, promptHash }, 'Failed to query cached AI explanation in database');
    throw new AppError(
      'Failed to query cached AI explanation',
      500,
      errorCodes.DATABASE_ERROR
    );
  }
}

module.exports = {
  create,
  findByPromptHash,
};

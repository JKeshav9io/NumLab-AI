'use strict';

const { prisma } = require('../index');
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
        solverRunId: data.solverRunId,
        focusMode: data.focusMode || 'steps',
        promptHash: data.promptHash,
        responseText: data.responseText,
        expiresAt: data.expiresAt || null,
      },
    });

    return explanation;
  } catch (error) {
    throw new AppError(
      'Failed to persist AI explanation',
      500,
      errorCodes.DATABASE_ERROR,
      { solverRunId: data.solverRunId, originalError: error.message }
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
    throw new AppError(
      'Failed to query cached AI explanation',
      500,
      errorCodes.DATABASE_ERROR,
      { promptHash, originalError: error.message }
    );
  }
}

module.exports = {
  create,
  findByPromptHash,
};

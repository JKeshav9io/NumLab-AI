'use strict';

const refreshTokenRepository = require('./repositories/refreshTokenRepository');
const aiExplanationRepository = require('./repositories/aiExplanationRepository');
const logger = require('../config/logger');

/**
 * Cleans up expired refresh tokens.
 * @param {Date} [now=new Date()]
 * @returns {Promise<number>} Count of deleted tokens
 */
async function cleanupExpiredRefreshTokens(now = new Date()) {
  return await refreshTokenRepository.deleteExpired(now);
}

/**
 * Cleans up expired AI explanations.
 * @param {Date} [now=new Date()]
 * @returns {Promise<number>} Count of deleted explanations
 */
async function cleanupExpiredAiExplanations(now = new Date()) {
  return await aiExplanationRepository.deleteExpired(now);
}

/**
 * Performs cleanup of all expired TTL records across refresh tokens and AI explanations.
 * @param {Date} [now=new Date()]
 * @returns {Promise<{ refreshTokensDeleted: number, aiExplanationsDeleted: number }>}
 */
async function cleanupExpiredRecords(now = new Date()) {
  const [refreshTokensDeleted, aiExplanationsDeleted] = await Promise.all([
    cleanupExpiredRefreshTokens(now),
    cleanupExpiredAiExplanations(now),
  ]);

  logger.info(
    { refreshTokensDeleted, aiExplanationsDeleted },
    'Completed TTL cleanup of expired records'
  );

  return {
    refreshTokensDeleted,
    aiExplanationsDeleted,
  };
}

module.exports = {
  cleanupExpiredRefreshTokens,
  cleanupExpiredAiExplanations,
  cleanupExpiredRecords,
};

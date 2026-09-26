'use strict';

const logger = require('../../config/logger');
const { generatePromptHash } = require('../../common/utils/cacheKey');
const { checkAiCallQuota } = require('../../common/middleware/rateLimiter');
const aiExplanationRepository = require('../../db/repositories/aiExplanationRepository');
const { buildExplainMessages } = require('./promptBuilder');
const { requestAiExplanation } = require('./openAiCompatibleClient');

// Named tuning constants
const CACHE_TTL_DAYS = 30;
const CACHE_TTL_MS = CACHE_TTL_DAYS * 24 * 60 * 60 * 1000;

/**
 * Generates or retrieves a cached AI explanation for a deterministic numerical computation.
 * @param {Object} params
 * @param {Object} params.solverResult - The numerical solver output object
 * @param {string} params.focus - Focus area ('summary' | 'steps' | 'warnings' | 'lab-report')
 * @param {boolean} [params.includeGraphSummary=false]
 * @param {string} [params.solverRunId] - Optional associated SolverRun UUID
 * @param {string} [params.clientIp] - Client IP for cost-aware rate limiting
 * @returns {Promise<Object>}
 */
async function explainSolverResult(params) {
  const { solverResult, focus = 'steps', includeGraphSummary = false, clientIp = 'anonymous', solverRunId = null } = params;

  // 1. Generate deterministic SHA-256 cache key from normalized solver output + focus
  const promptHash = generatePromptHash({
    solverResult,
    focus,
    includeGraphSummary,
  });

  // 2. Query cache for existing, non-expired explanation
  try {
    const cachedExplanation = await aiExplanationRepository.findByPromptHash(promptHash);

    if (cachedExplanation && cachedExplanation.responseText) {
      logger.info(
        { promptHash, focus, method: solverResult?.method },
        'AI explanation cache HIT — returning stored response'
      );

      return {
        explanation: cachedExplanation.responseText,
        focus: cachedExplanation.focusMode || focus,
        model: 'cached',
        usage: { total_tokens: 0, cached: true },
        cached: true,
        source: {
          method: solverResult.method,
          status: solverResult.status,
        },
      };
    }
  } catch (err) {
    // Non-fatal cache lookup error: log and fall through to AI provider
    logger.warn(
      { promptHash, err: err.message },
      'Cache lookup failed; proceeding with direct AI provider call'
    );
  }

  // 3. Cache MISS: Check cost-aware rate limit quota before billable API invocation
  logger.info(
    { promptHash, focus, method: solverResult?.method },
    'AI explanation cache MISS — querying AI provider'
  );
  checkAiCallQuota(clientIp);

  // 4. Request completion from OpenAI-compatible provider (with retry + circuit breaker)
  const messages = buildExplainMessages({
    solverResult,
    focus,
    includeGraphSummary,
  });
  const providerResult = await requestAiExplanation(messages);

  // 5. Asynchronous, non-blocking cache persistence
  const expiresAt = new Date(Date.now() + CACHE_TTL_MS);
  aiExplanationRepository
    .create({
      solverRunId,
      focusMode: focus,
      promptHash,
      responseText: providerResult.explanation,
      expiresAt,
    })
    .then(() => {
      logger.info({ promptHash, expiresAt }, 'AI explanation cached successfully');
    })
    .catch((err) => {
      logger.warn(
        { promptHash, err: err.message },
        'Non-fatal warning: Failed to persist AI explanation to database cache'
      );
    });

  // 6. Return response immediately to caller
  return {
    explanation: providerResult.explanation,
    focus,
    model: providerResult.model,
    usage: providerResult.usage,
    cached: false,
    source: {
      method: solverResult.method,
      status: solverResult.status,
    },
  };
}

module.exports = {
  explainSolverResult,
  CACHE_TTL_DAYS,
  CACHE_TTL_MS,
};

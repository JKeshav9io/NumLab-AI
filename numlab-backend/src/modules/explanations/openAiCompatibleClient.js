'use strict';

const env = require('../../config/env');
const logger = require('../../config/logger');
const { AppError, errorCodes } = require('../../common/errors');
const { aiCircuitBreaker } = require('./circuitBreaker');

// Named tuning constants
const isTest = process.env.NODE_ENV === 'test';
const MAX_RETRIES = 2; // 2 retries = 3 attempts total
const INITIAL_BACKOFF_MS = isTest ? 5 : 300; // Starting backoff delay in ms (accelerated in tests)
const BACKOFF_FACTOR = 2; // Multiplier per consecutive retry
const ESTIMATED_COST_PER_1K_TOKENS = 0.0015; // USD ~$0.0015 / 1K tokens for model tier

/**
 * Sleep helper for exponential backoff delays.
 * @param {number} ms
 * @returns {Promise<void>}
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Low-level single HTTP attempt to OpenAI-compatible provider.
 * Guarantees API keys and secrets are never leaked in errors or logs.
 * @param {Array} messages
 * @returns {Promise<Object>}
 */
async function sendSingleAttempt(messages) {
  if (typeof fetch !== 'function') {
    throw new AppError(
      'AI provider client requires global fetch support',
      500,
      errorCodes.AI_SERVICE_ERROR
    );
  }

  // Strict sanitization: base URL is read exclusively from verified env config (prevents SSRF)
  const endpoint = `${env.AI_BASE_URL.replace(/\/$/, '')}/chat/completions`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.AI_TIMEOUT_MS);
  let response;

  try {
    response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.AI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: env.AI_MODEL,
        messages,
        temperature: 0.2,
        max_tokens: env.AI_MAX_TOKENS,
      }),
      signal: controller.signal,
      keepalive: true, // Reuse TCP connections across requests
    });
  } catch (err) {
    const timedOut = err && err.name === 'AbortError';

    // Security guard: Ensure API key is never embedded in error messages or details
    throw new AppError(
      timedOut ? 'AI provider request timed out' : 'AI provider request failed',
      502,
      errorCodes.AI_SERVICE_ERROR,
      timedOut ? { timeoutMs: env.AI_TIMEOUT_MS } : { reason: 'Network connection failure' }
    );
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    throw new AppError(
      'AI provider request failed',
      502,
      errorCodes.AI_SERVICE_ERROR,
      { status: response.status }
    );
  }

  let payload;
  try {
    payload = await response.json();
  } catch (_err) {
    throw new AppError(
      'AI provider returned an invalid JSON response',
      502,
      errorCodes.AI_SERVICE_ERROR
    );
  }

  const explanation = payload.choices?.[0]?.message?.content;
  if (typeof explanation !== 'string' || explanation.trim() === '') {
    throw new AppError(
      'AI provider returned an invalid explanation response',
      502,
      errorCodes.AI_SERVICE_ERROR
    );
  }

  // Cost and token usage estimation logging (visibility, not billing)
  const usage = payload.usage || {};
  const totalTokens = usage.total_tokens || 0;
  const estimatedCostUsd = totalTokens > 0 ? (totalTokens / 1000) * ESTIMATED_COST_PER_1K_TOKENS : 0;

  logger.info(
    {
      model: payload.model || env.AI_MODEL,
      promptTokens: usage.prompt_tokens || 0,
      completionTokens: usage.completion_tokens || 0,
      totalTokens,
      estimatedCostUsd: Number(estimatedCostUsd.toFixed(6)),
    },
    'AI completion usage and cost estimate'
  );

  return {
    explanation: explanation.trim(),
    model: payload.model || env.AI_MODEL,
    usage,
  };
}

/**
 * Executes an AI explanation request with retry backoff and circuit breaker protection.
 * @param {Array} messages
 * @param {Object} [options]
 * @param {number} [options.maxRetries=MAX_RETRIES]
 * @param {number} [options.initialBackoffMs=INITIAL_BACKOFF_MS]
 * @returns {Promise<Object>}
 */
async function requestAiExplanation(messages, options = {}) {
  const maxRetries = options.maxRetries !== undefined ? options.maxRetries : MAX_RETRIES;
  const initialBackoffMs = options.initialBackoffMs !== undefined ? options.initialBackoffMs : INITIAL_BACKOFF_MS;

  return aiCircuitBreaker.execute(async () => {
    let attempt = 0;
    let currentBackoff = initialBackoffMs;

    while (attempt <= maxRetries) {
      try {
        return await sendSingleAttempt(messages);
      } catch (err) {
        attempt += 1;

        // Check if error is retryable (5xx status or network errors; NOT 4xx client errors)
        const httpStatus = err.details?.status;
        const is5xx = typeof httpStatus === 'number' ? httpStatus >= 500 : false;
        const isNetworkErr = err.details?.reason === 'Network connection failure';
        const isTimeout = err.details?.timeoutMs !== undefined;
        const isRetryable = is5xx || isNetworkErr || isTimeout;

        if (!isRetryable || attempt > maxRetries) {
          throw err;
        }

        logger.warn(
          {
            attempt,
            maxRetries,
            backoffMs: currentBackoff,
            errorCode: err.code,
            errorMessage: err.message,
          },
          'Transient AI provider failure, retrying with exponential backoff'
        );

        await sleep(currentBackoff);
        currentBackoff *= BACKOFF_FACTOR;
      }
    }
  });
}

module.exports = {
  requestAiExplanation,
  sendSingleAttempt,
  MAX_RETRIES,
  INITIAL_BACKOFF_MS,
  BACKOFF_FACTOR,
  ESTIMATED_COST_PER_1K_TOKENS,
};

'use strict';

const { AppError, errorCodes } = require('../../common/errors');

async function requestAiExplanation(messages) {
  if (typeof fetch !== 'function') {
    throw new AppError(
      'AI provider client requires global fetch support',
      500,
      errorCodes.AI_SERVICE_ERROR
    );
  }

  const env = require('../../config/env');
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
    });
  } catch (err) {
    const timedOut = err && err.name === 'AbortError';

    throw new AppError(
      timedOut ? 'AI provider request timed out' : 'AI provider request failed',
      502,
      errorCodes.AI_SERVICE_ERROR,
      timedOut ? { timeoutMs: env.AI_TIMEOUT_MS } : null
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

  return {
    explanation: explanation.trim(),
    model: payload.model || env.AI_MODEL,
    usage: payload.usage || {},
  };
}

module.exports = {
  requestAiExplanation,
};

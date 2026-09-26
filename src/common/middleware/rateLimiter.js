'use strict';

const rateLimit = require('express-rate-limit');
const { AppError, errorCodes } = require('../errors');

const isTest = process.env.NODE_ENV === 'test';

// Named tuning constants
const SOLVE_LIMIT_WINDOW_MS = 60 * 1000;
const SOLVE_LIMIT_MAX = isTest ? 1000 : 30;

const EXPLAIN_LIMIT_WINDOW_MS = 60 * 1000;
const EXPLAIN_LIMIT_MAX = isTest ? 1000 : 20;

const AUTH_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const AUTH_LIMIT_MAX = isTest ? 1000 : 10;

const REPORT_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const REPORT_LIMIT_MAX = isTest ? 1000 : 10;

const AI_CALL_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const AI_CALL_LIMIT_MAX = isTest ? 1000 : 10;

const solveLimiter = rateLimit({
  windowMs: SOLVE_LIMIT_WINDOW_MS,
  limit: SOLVE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
});

const explainLimiter = rateLimit({
  windowMs: EXPLAIN_LIMIT_WINDOW_MS,
  limit: EXPLAIN_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
});

// Stricter rate limit for authentication endpoints to prevent password brute-forcing
const authLimiter = rateLimit({
  windowMs: AUTH_LIMIT_WINDOW_MS,
  limit: AUTH_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: {
      code: errorCodes.RATE_LIMIT_EXCEEDED,
      message: 'Too many authentication attempts. Please try again in 15 minutes.',
    },
  },
});

function createReportLimiter(options = {}) {
  return rateLimit({
    windowMs: options.windowMs || REPORT_LIMIT_WINDOW_MS,
    limit: options.limit || REPORT_LIMIT_MAX,
    standardHeaders: true,
    legacyHeaders: false,
    validate: false,
    keyGenerator: (req) => req.user?.id || req.ip || 'anonymous',
    message: {
      success: false,
      error: {
        code: errorCodes.RATE_LIMIT_EXCEEDED,
        message: 'Report generation quota exceeded. Please wait 15 minutes before requesting more PDF reports.',
      },
    },
    ...options,
  });
}

// User-centric rate limiter for CPU-intensive PDF report generation (10 reports / 15m)
const reportLimiter = createReportLimiter();

// In-memory sliding window budget tracker for uncached billable AI provider calls
const aiCallTracker = new Map();

/**
 * Checks and records an uncached AI provider call against the cost budget quota.
 * Cache hits bypass this check entirely.
 * @param {string} [identifier='anonymous'] - Client IP or user identifier
 */
function checkAiCallQuota(identifier = 'anonymous') {
  const now = Date.now();
  const windowStart = now - AI_CALL_LIMIT_WINDOW_MS;
  const timestamps = (aiCallTracker.get(identifier) || []).filter((t) => t > windowStart);

  if (timestamps.length >= AI_CALL_LIMIT_MAX) {
    const oldest = timestamps[0];
    const retryAfterSeconds = Math.ceil((oldest + AI_CALL_LIMIT_WINDOW_MS - now) / 1000);
    throw new AppError(
      'Uncached AI explanation quota exceeded. Please wait before generating new explanations.',
      429,
      errorCodes.RATE_LIMIT_EXCEEDED,
      { retryAfterSeconds }
    );
  }

  timestamps.push(now);
  aiCallTracker.set(identifier, timestamps);
}

/**
 * Resets the in-memory AI quota tracker (for unit/integration testing).
 */
function resetAiCallQuota() {
  aiCallTracker.clear();
}

module.exports = {
  solveLimiter,
  explainLimiter,
  authLimiter,
  reportLimiter,
  createReportLimiter,
  checkAiCallQuota,
  resetAiCallQuota,
  SOLVE_LIMIT_WINDOW_MS,
  SOLVE_LIMIT_MAX,
  EXPLAIN_LIMIT_WINDOW_MS,
  EXPLAIN_LIMIT_MAX,
  AUTH_LIMIT_WINDOW_MS,
  AUTH_LIMIT_MAX,
  REPORT_LIMIT_WINDOW_MS,
  REPORT_LIMIT_MAX,
  AI_CALL_LIMIT_WINDOW_MS,
  AI_CALL_LIMIT_MAX,
};


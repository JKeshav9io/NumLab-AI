'use strict';

const rateLimit = require('express-rate-limit');

const solveLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
});

const explainLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = {
  solveLimiter,
  explainLimiter,
};

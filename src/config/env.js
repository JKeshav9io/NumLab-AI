'use strict';

require('dotenv').config({ quiet: true });

const required = [
  'NODE_ENV',
  'PORT',
  'DATABASE_URL',
  'JWT_SECRET',
  'AI_API_KEY',
];

for (const key of required) {
  if (!process.env[key]) {
    console.error(`Missing required environment variable: ${key}`);
    process.exit(1);
  }
}

// Security guardrail: Require strong secret in production; warn in development/test
if (
  process.env.JWT_SECRET === 'change-this-to-a-long-random-string' ||
  process.env.JWT_SECRET.length < 32
) {
  if (process.env.NODE_ENV === 'production') {
    console.error(
      '[config] ❌ FATAL SECURITY ERROR: JWT_SECRET appears to use a default placeholder or is under 32 characters. Production requires a cryptographically secure secret of at least 32 characters.'
    );
    process.exit(1);
  } else {
    console.warn(
      '[config] ⚠️  SECURITY WARNING: JWT_SECRET appears to use a default placeholder or is under 32 characters. Ensure a cryptographically secure 256-bit random secret is set in production.'
    );
  }
}

function parseIntegerEnv(key, fallback) {
  const rawValue = process.env[key] || fallback;
  const parsed = parseInt(rawValue, 10);

  if (Number.isNaN(parsed)) {
    console.error(`Invalid integer environment variable: ${key}`);
    process.exit(1);
  }

  return parsed;
}

function parsePositiveIntegerEnv(key, fallback) {
  const parsed = parseIntegerEnv(key, fallback);

  if (parsed <= 0) {
    console.error(`Invalid positive integer environment variable: ${key}`);
    process.exit(1);
  }

  return parsed;
}

module.exports = {
  NODE_ENV: process.env.NODE_ENV,
  PORT: parseIntegerEnv('PORT'),

  DATABASE_URL: process.env.DATABASE_URL,

  JWT_SECRET: process.env.JWT_SECRET || null,
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',

  AI_API_KEY: process.env.AI_API_KEY,
  AI_MODEL: process.env.AI_MODEL || 'gpt-4o-mini',
  AI_BASE_URL: process.env.AI_BASE_URL || 'https://api.openai.com/v1',
  AI_MAX_TOKENS: parsePositiveIntegerEnv('AI_MAX_TOKENS', '700'),
  AI_TIMEOUT_MS: parsePositiveIntegerEnv('AI_TIMEOUT_MS', '15000'),

  STORAGE_BUCKET: process.env.STORAGE_BUCKET || 'numlab-reports',
  STORAGE_REGION: process.env.STORAGE_REGION || 'us-east-1',
};

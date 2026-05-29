'use strict';

require('dotenv').config({ quiet: true });

const required = [
  'NODE_ENV',
  'PORT',
  'DB_HOST',
  'DB_NAME',
  'DB_USER',
  'DB_PASSWORD',
  'JWT_SECRET',
  'AI_API_KEY',
];

for (const key of required) {
  if (!process.env[key]) {
    console.error(`Missing required environment variable: ${key}`);
    process.exit(1);
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

  DB_HOST: process.env.DB_HOST,
  DB_PORT: parseIntegerEnv('DB_PORT', '5432'),
  DB_NAME: process.env.DB_NAME,
  DB_USER: process.env.DB_USER,
  DB_PASSWORD: process.env.DB_PASSWORD,

  JWT_SECRET: process.env.JWT_SECRET,
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',

  AI_API_KEY: process.env.AI_API_KEY,
  AI_MODEL: process.env.AI_MODEL || 'gpt-4o-mini',
  AI_BASE_URL: process.env.AI_BASE_URL || 'https://api.openai.com/v1',
  AI_MAX_TOKENS: parsePositiveIntegerEnv('AI_MAX_TOKENS', '700'),
  AI_TIMEOUT_MS: parsePositiveIntegerEnv('AI_TIMEOUT_MS', '15000'),

  STORAGE_BUCKET: process.env.STORAGE_BUCKET || 'numlab-reports',
  STORAGE_REGION: process.env.STORAGE_REGION || 'us-east-1',
};

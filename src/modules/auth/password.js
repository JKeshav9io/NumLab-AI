'use strict';

const bcrypt = require('bcrypt');

// Cost factor: 12 rounds (~250-350ms per hash on modern CPUs)
// Tradeoff:
// - 10 rounds is too fast on modern GPUs (~50-80ms), making offline brute-force feasible.
// - 14 rounds takes >1.2s per operation, creating a denial-of-service vector on high login concurrency.
// - 12 rounds strikes the optimal security/performance balance per OWASP guidelines.
const SALT_ROUNDS = 12;

/**
 * Hashes a plaintext password using bcrypt with salt rounds 12.
 * @param {string} plainText
 * @returns {Promise<string>}
 */
async function hashPassword(plainText) {
  return bcrypt.hash(plainText, SALT_ROUNDS);
}

/**
 * Verifies a plaintext password against a stored bcrypt hash.
 * @param {string} plainText
 * @param {string} hash
 * @returns {Promise<boolean>}
 */
async function verifyPassword(plainText, hash) {
  if (!plainText || !hash) return false;
  return bcrypt.compare(plainText, hash);
}

module.exports = {
  SALT_ROUNDS,
  hashPassword,
  verifyPassword,
};

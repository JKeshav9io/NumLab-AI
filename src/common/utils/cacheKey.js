'use strict';

const crypto = require('crypto');

/**
 * Recursively sorts object keys to produce a deterministic representation.
 * @param {*} value
 * @returns {*}
 */
function canonicalize(value) {
  if (value === null || typeof value !== 'object') {
    return value;
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (Array.isArray(value)) {
    return value.map(canonicalize);
  }

  const sortedObj = {};
  const keys = Object.keys(value).sort();
  for (const key of keys) {
    if (value[key] !== undefined) {
      sortedObj[key] = canonicalize(value[key]);
    }
  }

  return sortedObj;
}

/**
 * Returns a stable, deterministic JSON string with sorted keys and no whitespace variance.
 * @param {*} value
 * @returns {string}
 */
function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

/**
 * Generates a deterministic SHA-256 hash for caching AI explanations based on solver output and focus.
 * @param {Object} params
 * @param {Object} params.solverResult
 * @param {string} params.focus
 * @param {boolean} [params.includeGraphSummary]
 * @returns {string} 64-character hex SHA-256 string
 */
function generatePromptHash({ solverResult, focus = 'steps', includeGraphSummary = false }) {
  const normalized = {
    solverResult: {
      method: solverResult?.method || '',
      status: solverResult?.status || '',
      input: solverResult?.input || {},
      finalAnswer: solverResult?.finalAnswer || {},
      warnings: Array.isArray(solverResult?.warnings) ? solverResult.warnings : [],
      iterations: Array.isArray(solverResult?.iterations) ? solverResult.iterations : [],
      graphData: includeGraphSummary ? (solverResult?.graphData || null) : null,
    },
    focus,
    includeGraphSummary: Boolean(includeGraphSummary),
  };

  const canonicalString = canonicalJson(normalized);
  return crypto.createHash('sha256').update(canonicalString).digest('hex');
}

module.exports = {
  canonicalize,
  canonicalJson,
  generatePromptHash,
};

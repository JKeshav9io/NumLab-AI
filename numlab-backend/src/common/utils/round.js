'use strict';

/**
 * Rounds a floating point number to a given number of decimal places.
 * Normalizes -0 to 0.
 * @param {number} value
 * @param {number} [decimals=10]
 * @returns {number}
 */
function round(value, decimals = 10) {
  const rounded = Number.parseFloat(value.toFixed(decimals));
  return Object.is(rounded, -0) ? 0 : rounded;
}

module.exports = round;
module.exports.round = round;

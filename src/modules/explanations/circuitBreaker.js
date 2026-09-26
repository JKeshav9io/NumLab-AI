'use strict';

const logger = require('../../config/logger');
const { AppError, errorCodes } = require('../../common/errors');

// Named tuning constants
const DEFAULT_FAILURE_THRESHOLD = 5;
const DEFAULT_COOLDOWN_MS = 30000; // 30 seconds

class CircuitBreaker {
  /**
   * @param {Object} [options]
   * @param {number} [options.failureThreshold=5] - Consecutive failures before opening circuit
   * @param {number} [options.cooldownMs=30000] - Time in ms before attempting HALF_OPEN probe
   * @param {string} [options.name='ai-provider'] - Name for logging purposes
   */
  constructor(options = {}) {
    this.name = options.name || 'ai-provider';
    this.failureThreshold = options.failureThreshold || DEFAULT_FAILURE_THRESHOLD;
    this.cooldownMs = options.cooldownMs || DEFAULT_COOLDOWN_MS;

    this.state = 'CLOSED'; // 'CLOSED' | 'OPEN' | 'HALF_OPEN'
    this.consecutiveFailures = 0;
    this.lastFailureTime = null;
  }

  /**
   * Returns the current state of the circuit breaker.
   * Checks if cooldown period has elapsed to promote OPEN to HALF_OPEN.
   * @returns {'CLOSED' | 'OPEN' | 'HALF_OPEN'}
   */
  getState() {
    if (this.state === 'OPEN') {
      const elapsed = Date.now() - (this.lastFailureTime || 0);
      if (elapsed >= this.cooldownMs) {
        this.transitionTo('HALF_OPEN');
      }
    }
    return this.state;
  }

  /**
   * Transitions the circuit to a new state and logs the change.
   * @param {'CLOSED' | 'OPEN' | 'HALF_OPEN'} newState
   * @private
   */
  transitionTo(newState) {
    const oldState = this.state;
    if (oldState === newState) return;

    this.state = newState;
    logger.warn(
      {
        circuit: this.name,
        fromState: oldState,
        toState: newState,
        consecutiveFailures: this.consecutiveFailures,
      },
      `Circuit breaker state transition: ${oldState} -> ${newState}`
    );
  }

  /**
   * Executes a protected action through the circuit breaker.
   * @template T
   * @param {() => Promise<T>} action
   * @returns {Promise<T>}
   */
  async execute(action) {
    const currentState = this.getState();

    if (currentState === 'OPEN') {
      const cooldownRemainingMs = Math.max(
        0,
        this.cooldownMs - (Date.now() - (this.lastFailureTime || 0))
      );

      throw new AppError(
        'AI service is temporarily unavailable (circuit breaker is open)',
        502,
        errorCodes.AI_SERVICE_ERROR,
        {
          circuitState: 'OPEN',
          cooldownRemainingMs,
        }
      );
    }

    try {
      const result = await action();
      this.recordSuccess();
      return result;
    } catch (err) {
      // Only count system/network/5xx errors towards circuit failure threshold
      // (Do NOT trip the breaker on 4xx user validation errors)
      if (this.isProviderFailure(err)) {
        this.recordFailure();
      }
      throw err;
    }
  }

  /**
   * Records a successful execution and resets the breaker if needed.
   */
  recordSuccess() {
    if (this.state === 'HALF_OPEN') {
      this.consecutiveFailures = 0;
      this.transitionTo('CLOSED');
    } else if (this.state === 'CLOSED') {
      this.consecutiveFailures = 0;
    }
  }

  /**
   * Records a failed execution and trips the circuit if threshold is reached.
   */
  recordFailure() {
    this.consecutiveFailures += 1;
    this.lastFailureTime = Date.now();

    if (this.state === 'HALF_OPEN') {
      this.transitionTo('OPEN');
    } else if (this.state === 'CLOSED' && this.consecutiveFailures >= this.failureThreshold) {
      this.transitionTo('OPEN');
    }
  }

  /**
   * Determines if an error counts as a provider/system failure for circuit health.
   * @param {Error} err
   * @returns {boolean}
   */
  isProviderFailure(err) {
    if (err instanceof AppError) {
      // 5xx status codes or AI_SERVICE_ERROR represent upstream provider failure
      return err.statusCode >= 500;
    }
    // Generic errors / network exceptions
    return true;
  }

  /**
   * Manually resets the circuit breaker to CLOSED (useful for testing).
   */
  reset() {
    this.state = 'CLOSED';
    this.consecutiveFailures = 0;
    this.lastFailureTime = null;
  }
}

// Global singleton instance for AI provider
const aiCircuitBreaker = new CircuitBreaker();

module.exports = {
  CircuitBreaker,
  aiCircuitBreaker,
  DEFAULT_FAILURE_THRESHOLD,
  DEFAULT_COOLDOWN_MS,
};

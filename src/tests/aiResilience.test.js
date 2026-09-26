'use strict';

const { CircuitBreaker } = require('../modules/explanations/circuitBreaker');
const { checkAiCallQuota, resetAiCallQuota, AI_CALL_LIMIT_MAX } = require('../common/middleware/rateLimiter');
const { AppError } = require('../common/errors');

describe('AI Resilience Layer (CircuitBreaker & Cost Quota)', () => {
  describe('CircuitBreaker state machine', () => {
    let breaker;

    beforeEach(() => {
      breaker = new CircuitBreaker({
        failureThreshold: 3,
        cooldownMs: 50, // 50ms cooldown for fast unit tests
        name: 'test-circuit',
      });
    });

    test('initial state is CLOSED', () => {
      expect(breaker.getState()).toBe('CLOSED');
    });

    test('stays CLOSED on fewer failures than threshold', async () => {
      const failingAction = jest.fn().mockRejectedValue(new Error('Network error'));

      await expect(breaker.execute(failingAction)).rejects.toThrow('Network error');
      await expect(breaker.execute(failingAction)).rejects.toThrow('Network error');

      expect(breaker.getState()).toBe('CLOSED');
      expect(breaker.consecutiveFailures).toBe(2);
    });

    test('opens after consecutive failures hit threshold', async () => {
      const failingAction = jest.fn().mockRejectedValue(new Error('Network error'));

      await expect(breaker.execute(failingAction)).rejects.toThrow('Network error');
      await expect(breaker.execute(failingAction)).rejects.toThrow('Network error');
      await expect(breaker.execute(failingAction)).rejects.toThrow('Network error');

      expect(breaker.getState()).toBe('OPEN');
    });

    test('fast-fails immediately without calling action when OPEN', async () => {
      const failingAction = jest.fn().mockRejectedValue(new Error('Network error'));
      const targetAction = jest.fn().mockResolvedValue('success');

      // Trip the breaker
      for (let i = 0; i < 3; i++) {
        await expect(breaker.execute(failingAction)).rejects.toThrow();
      }

      expect(breaker.getState()).toBe('OPEN');

      // Call action while OPEN
      await expect(breaker.execute(targetAction)).rejects.toThrow(
        'AI service is temporarily unavailable (circuit breaker is open)'
      );
      // Action must NOT have been called
      expect(targetAction).not.toHaveBeenCalled();
    });

    test('transitions to HALF_OPEN after cooldown and recovers to CLOSED on success', async () => {
      const failingAction = jest.fn().mockRejectedValue(new Error('Network error'));
      const successfulAction = jest.fn().mockResolvedValue({ explanation: 'Recovered' });

      for (let i = 0; i < 3; i++) {
        await expect(breaker.execute(failingAction)).rejects.toThrow();
      }
      expect(breaker.getState()).toBe('OPEN');

      // Wait for cooldown
      await new Promise((resolve) => setTimeout(resolve, 60));

      expect(breaker.getState()).toBe('HALF_OPEN');

      // Successful probe request closes circuit
      const result = await breaker.execute(successfulAction);
      expect(result).toEqual({ explanation: 'Recovered' });
      expect(breaker.getState()).toBe('CLOSED');
      expect(breaker.consecutiveFailures).toBe(0);
    });

    test('reopens immediately if probe request fails during HALF_OPEN', async () => {
      const failingAction = jest.fn().mockRejectedValue(new Error('Network error'));

      for (let i = 0; i < 3; i++) {
        await expect(breaker.execute(failingAction)).rejects.toThrow();
      }
      expect(breaker.getState()).toBe('OPEN');

      // Wait for cooldown
      await new Promise((resolve) => setTimeout(resolve, 60));
      expect(breaker.getState()).toBe('HALF_OPEN');

      // Probe failure re-opens circuit
      await expect(breaker.execute(failingAction)).rejects.toThrow('Network error');
      expect(breaker.getState()).toBe('OPEN');
    });
  });

  describe('Cost-Aware AI Call Quota Tracker', () => {
    beforeEach(() => {
      resetAiCallQuota();
    });

    test('allows calls within quota and throws 429 when quota is exceeded', () => {
      const testIp = '192.168.1.100';

      // Spend full quota
      for (let i = 0; i < AI_CALL_LIMIT_MAX; i++) {
        expect(() => checkAiCallQuota(testIp)).not.toThrow();
      }

      // Next uncached call must throw 429 RATE_LIMIT_EXCEEDED
      expect(() => checkAiCallQuota(testIp)).toThrow(AppError);
      try {
        checkAiCallQuota(testIp);
      } catch (err) {
        expect(err.statusCode).toBe(429);
        expect(err.code).toBe('RATE_LIMIT_EXCEEDED');
        expect(err.details.retryAfterSeconds).toBeGreaterThan(0);
      }
    });

    test('tracks quotas independently per client identifier', () => {
      const ip1 = '10.0.0.1';
      const ip2 = '10.0.0.2';

      for (let i = 0; i < AI_CALL_LIMIT_MAX; i++) {
        checkAiCallQuota(ip1);
      }

      // IP1 is blocked
      expect(() => checkAiCallQuota(ip1)).toThrow();

      // IP2 still has full quota available
      expect(() => checkAiCallQuota(ip2)).not.toThrow();
    });
  });
});

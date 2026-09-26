'use strict';

const originalFetch = global.fetch;
const originalEnv = process.env;
const { prisma } = require('../db');
const { aiCircuitBreaker } = require('../modules/explanations/circuitBreaker');
const { resetAiCallQuota } = require('../common/middleware/rateLimiter');
const aiExplanationRepository = require('../db/repositories/aiExplanationRepository');

describe('Explanation API with Hardened Resilience & Caching', () => {
  beforeEach(() => {
    aiCircuitBreaker.reset();
    resetAiCallQuota();
    jest.spyOn(aiExplanationRepository, 'create').mockResolvedValue({});

    process.env = {
      ...originalEnv,
      NODE_ENV: 'test',
      PORT: '3000',
      DB_HOST: 'localhost',
      DB_NAME: 'numlab',
      DB_USER: 'numlab_user',
      DB_PASSWORD: 'changeme',
      JWT_SECRET: 'test-secret',
      AI_API_KEY: 'test-key',
      AI_MODEL: 'test-model',
      AI_BASE_URL: 'https://example.test/v1',
    };

    global.fetch = jest.fn((url, options) => {
      if (String(url).startsWith('http://127.0.0.1')) {
        return originalFetch(url, options);
      }

      return Promise.reject(new Error('Unexpected AI provider call'));
    });
  });

  afterEach(() => {
    global.fetch = originalFetch;
    process.env = originalEnv;
    aiCircuitBreaker.reset();
    aiExplanationRepository.create.mockRestore?.();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('POST /api/v1/explain returns a structured AI explanation on cache miss', async () => {
    jest.spyOn(aiExplanationRepository, 'findByPromptHash').mockResolvedValueOnce(null);

    global.fetch.mockImplementation((url, options) => {
      if (String(url).startsWith('http://127.0.0.1')) {
        return originalFetch(url, options);
      }

      return Promise.resolve({
        ok: true,
        json: async () => ({
          model: 'test-model',
          choices: [
            {
              message: {
                content: 'The method converged by narrowing the interval.',
              },
            },
          ],
          usage: {
            prompt_tokens: 10,
            completion_tokens: 8,
          },
        }),
      });
    });
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/explain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          solverResult: buildSolverResult(),
          focus: 'steps',
          includeGraphSummary: true,
        }),
      });
      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data.explanation).toBe('The method converged by narrowing the interval.');
      expect(body.data.focus).toBe('steps');
      expect(body.data.model).toBe('test-model');
      expect(body.data.cached).toBe(false);
      expect(body.data.usage.prompt_tokens).toBe(10);
      expect(body.data.source).toEqual({
        method: 'Bisection Method',
        status: 'converged',
      });

      expect(getProviderCalls()).toHaveLength(1);
      const providerRequest = JSON.parse(getProviderCalls()[0][1].body);
      expect(providerRequest.max_tokens).toBe(700);
      expect(providerRequest.temperature).toBe(0.2);
    } finally {
      await closeServer(server);
      aiExplanationRepository.findByPromptHash.mockRestore?.();
    }
  });

  test('POST /api/v1/explain returns cached result on cache hit without calling AI provider', async () => {
    const cachedText = 'This is a stored explanation from database cache.';
    jest.spyOn(aiExplanationRepository, 'findByPromptHash').mockResolvedValueOnce({
      id: 'mock-id',
      focusMode: 'steps',
      responseText: cachedText,
      expiresAt: new Date(Date.now() + 1000000),
    });

    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/explain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          solverResult: buildSolverResult(),
          focus: 'steps',
        }),
      });
      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data.explanation).toBe(cachedText);
      expect(body.data.cached).toBe(true);
      expect(body.data.model).toBe('cached');
      // Assert AI provider was NOT called
      expect(getProviderCalls()).toHaveLength(0);
    } finally {
      await closeServer(server);
      aiExplanationRepository.findByPromptHash.mockRestore?.();
    }
  });

  test('POST /api/v1/explain retries on 5xx failure and succeeds on subsequent attempt', async () => {
    jest.spyOn(aiExplanationRepository, 'findByPromptHash').mockResolvedValueOnce(null);

    let attempts = 0;
    global.fetch.mockImplementation((url, options) => {
      if (String(url).startsWith('http://127.0.0.1')) {
        return originalFetch(url, options);
      }

      attempts += 1;
      if (attempts === 1) {
        return Promise.resolve({
          ok: false,
          status: 503,
          json: async () => ({ error: 'Service Unavailable' }),
        });
      }

      return Promise.resolve({
        ok: true,
        json: async () => ({
          model: 'test-model',
          choices: [{ message: { content: 'Success on retry attempt.' } }],
          usage: { total_tokens: 20 },
        }),
      });
    });

    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/explain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          solverResult: buildSolverResult(),
          focus: 'summary',
        }),
      });
      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data.explanation).toBe('Success on retry attempt.');
      expect(attempts).toBe(2);
    } finally {
      await closeServer(server);
      aiExplanationRepository.findByPromptHash.mockRestore?.();
    }
  });

  test('POST /api/v1/explain does NOT retry on 4xx client errors from AI provider', async () => {
    jest.spyOn(aiExplanationRepository, 'findByPromptHash').mockResolvedValueOnce(null);

    let attempts = 0;
    global.fetch.mockImplementation((url, options) => {
      if (String(url).startsWith('http://127.0.0.1')) {
        return originalFetch(url, options);
      }

      attempts += 1;
      return Promise.resolve({
        ok: false,
        status: 400,
        json: async () => ({ error: 'Bad Request' }),
      });
    });

    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/explain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          solverResult: buildSolverResult(),
          focus: 'steps',
        }),
      });
      const body = await response.json();

      expect(response.status).toBe(502);
      expect(body.success).toBe(false);
      expect(attempts).toBe(1); // Exactly 1 attempt, no retries
    } finally {
      await closeServer(server);
      aiExplanationRepository.findByPromptHash.mockRestore?.();
    }
  });

  test('Circuit breaker opens after threshold failures and fast-fails without network calls', async () => {
    jest.spyOn(aiExplanationRepository, 'findByPromptHash').mockResolvedValue(null);

    global.fetch.mockImplementation((url, options) => {
      if (String(url).startsWith('http://127.0.0.1')) {
        return originalFetch(url, options);
      }

      return Promise.resolve({
        ok: false,
        status: 500,
        json: async () => ({}),
      });
    });

    // Manually trip the circuit breaker by recording failures
    for (let i = 0; i < 5; i++) {
      aiCircuitBreaker.recordFailure();
    }

    expect(aiCircuitBreaker.getState()).toBe('OPEN');

    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/explain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          solverResult: buildSolverResult(),
        }),
      });
      const body = await response.json();

      expect(response.status).toBe(502);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('AI_SERVICE_ERROR');
      expect(body.error.message).toContain('circuit breaker is open');
      // Verify no external AI fetch calls were attempted while circuit is open
      expect(getProviderCalls()).toHaveLength(0);
    } finally {
      await closeServer(server);
      aiExplanationRepository.findByPromptHash.mockRestore?.();
    }
  });

  test.each([
    [
      'too many iterations',
      {
        solverResult: {
          ...buildSolverResult(),
          iterations: Array.from({ length: 201 }, (_value, index) => ({ iteration: index + 1 })),
        },
      },
    ],
    [
      'too many graphData array points',
      {
        solverResult: {
          ...buildSolverResult(),
          graphData: Array.from({ length: 501 }, (_value, index) => ({ x: index, y: index })),
        },
      },
    ],
    [
      'too many nested graphData points',
      {
        solverResult: {
          ...buildSolverResult(),
          graphData: {
            sampledCurve: Array.from({ length: 501 }, (_value, index) => ({ x: index, y: index })),
          },
        },
      },
    ],
  ])('POST /api/v1/explain rejects %s', async (_name, requestBody) => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/explain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
      });
      const body = await response.json();

      expect(response.status).toBe(400);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('VALIDATION_ERROR');
      expect(getProviderCalls()).toHaveLength(0);
    } finally {
      await closeServer(server);
    }
  });

  test.each([
    ['missing solverResult', {}],
    ['missing method', { solverResult: { status: 'converged', finalAnswer: {} } }],
    ['missing status', { solverResult: { method: 'Bisection Method', finalAnswer: {} } }],
    ['missing finalAnswer', { solverResult: { method: 'Bisection Method', status: 'converged' } }],
  ])('POST /api/v1/explain validates %s', async (_name, requestBody) => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/explain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
      });
      const body = await response.json();

      expect(response.status).toBe(400);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('VALIDATION_ERROR');
      expect(getProviderCalls()).toHaveLength(0);
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/explain maps provider timeouts to AI_SERVICE_ERROR', async () => {
    jest.spyOn(aiExplanationRepository, 'findByPromptHash').mockResolvedValueOnce(null);

    global.fetch.mockImplementation((url, options) => {
      if (String(url).startsWith('http://127.0.0.1')) {
        return originalFetch(url, options);
      }

      const err = new Error('The operation was aborted');
      err.name = 'AbortError';
      return Promise.reject(err);
    });
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/explain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          solverResult: buildSolverResult(),
        }),
      });
      const body = await response.json();

      expect(response.status).toBe(502);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('AI_SERVICE_ERROR');
      expect(body.error.details.timeoutMs).toBeDefined();
    } finally {
      await closeServer(server);
      aiExplanationRepository.findByPromptHash.mockRestore?.();
    }
  });
});

function buildSolverResult() {
  return {
    method: 'Bisection Method',
    status: 'converged',
    input: {
      equation: 'x^2 - 4',
      lowerBound: 0,
      upperBound: 3,
    },
    iterations: [
      {
        iteration: 1,
        c: 1.5,
        fC: -1.75,
      },
    ],
    finalAnswer: {
      root: 2,
      converged: true,
      reason: 'Tolerance reached',
    },
    warnings: [],
    executionTimeMs: 2,
  };
}

function getProviderCalls() {
  return global.fetch.mock.calls.filter(([url]) => !String(url).startsWith('http://127.0.0.1'));
}

async function startApp() {
  const createApp = require('../app');
  const app = createApp();
  const server = app.listen(0);
  const { port } = server.address();

  return {
    server,
    baseUrl: `http://127.0.0.1:${port}`,
  };
}

function closeServer(server) {
  return new Promise((resolve, reject) => {
    server.close((err) => {
      if (err) reject(err);
      else resolve();
    });
  });
}

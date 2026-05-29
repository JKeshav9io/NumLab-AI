'use strict';

const originalFetch = global.fetch;
const originalEnv = process.env;

describe('Explanation API', () => {
  beforeEach(() => {
    jest.resetModules();
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
  });

  test('POST /api/v1/explain returns a structured AI explanation', async () => {
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
      expect(body.data.usage.prompt_tokens).toBe(10);
      expect(body.data.source).toEqual({
        method: 'Bisection Method',
        status: 'converged',
      });

      expect(getProviderCalls()).toHaveLength(1);
      const providerRequest = JSON.parse(getProviderCalls()[0][1].body);
      expect(providerRequest.max_tokens).toBe(700);
      expect(providerRequest.temperature).toBe(0.2);
      expect(global.fetch).toHaveBeenCalledWith(
        'https://example.test/v1/chat/completions',
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            Authorization: 'Bearer test-key',
            'Content-Type': 'application/json',
          }),
        })
      );
    } finally {
      await closeServer(server);
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

  test('POST /api/v1/explain maps provider failures to AI_SERVICE_ERROR', async () => {
    global.fetch.mockImplementation((url, options) => {
      if (String(url).startsWith('http://127.0.0.1')) {
        return originalFetch(url, options);
      }

      return Promise.resolve({
        ok: false,
        status: 503,
        json: async () => ({}),
      });
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
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/explain maps provider timeouts to AI_SERVICE_ERROR', async () => {
    process.env.AI_TIMEOUT_MS = '1';
    global.fetch.mockImplementation((url, options) => {
      if (String(url).startsWith('http://127.0.0.1')) {
        return originalFetch(url, options);
      }

      return new Promise((_resolve, reject) => {
        options.signal.addEventListener('abort', () => {
          const err = new Error('aborted');
          err.name = 'AbortError';
          reject(err);
        });
      });
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
      expect(body.error.details.timeoutMs).toBe(1);
    } finally {
      await closeServer(server);
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

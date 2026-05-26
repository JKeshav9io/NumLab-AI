'use strict';

describe('Root-finding API', () => {
  test.each([
    [
      '/api/v1/solve/root/newton',
      {
        equation: 'x^3 - x - 2',
        derivativeEquation: '3*x^2 - 1',
        initialGuess: 1.5,
        tolerance: 0.0001,
        maxIterations: 100,
        includeGraphData: false,
      },
      'Newton-Raphson Method',
    ],
    [
      '/api/v1/solve/root/secant',
      {
        equation: 'x^3 - x - 2',
        firstGuess: 1,
        secondGuess: 2,
        tolerance: 0.0001,
        maxIterations: 100,
        includeGraphData: false,
      },
      'Secant Method',
    ],
    [
      '/api/v1/solve/root/regula-falsi',
      {
        equation: 'x^3 - x - 2',
        lowerBound: 1,
        upperBound: 2,
        tolerance: 0.0001,
        maxIterations: 100,
        includeGraphData: false,
      },
      'Regula Falsi Method',
    ],
  ])('POST %s returns a structured result', async (path, requestBody, methodName) => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
      });
      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data.method).toBe(methodName);
      expect(body.data.status).toBe('converged');
      expect(body.data.finalAnswer.root).toBeCloseTo(1.5214, 3);
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/solve/root/secant validates distinct guesses', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/solve/root/secant`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          equation: 'x^3 - x - 2',
          firstGuess: 1,
          secondGuess: 1,
        }),
      });
      const body = await response.json();

      expect(response.status).toBe(400);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    } finally {
      await closeServer(server);
    }
  });
});

async function startApp() {
  jest.resetModules();
  process.env.NODE_ENV = 'test';

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

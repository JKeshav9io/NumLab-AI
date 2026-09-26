'use strict';

describe('Root-finding API', () => {
  let server;
  let baseUrl;

  beforeAll(async () => {
    const appContext = await startApp();
    server = appContext.server;
    baseUrl = appContext.baseUrl;
  });

  afterAll(async () => {
    await closeServer(server);
  });

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
  });

  test('POST /api/v1/solve/root/secant validates distinct guesses', async () => {
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
  });
});

async function startApp() {
  process.env.NODE_ENV = 'test';

  const solverRunRepository = require('../db/repositories/solverRunRepository');
  jest.spyOn(solverRunRepository, 'create').mockResolvedValue({});

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

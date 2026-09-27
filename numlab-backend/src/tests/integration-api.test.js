'use strict';

describe('Integration API', () => {
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
      '/api/v1/solve/integration/trapezoidal',
      {
        equation: 'x^2',
        lowerBound: 0,
        upperBound: 1,
        subintervals: 4,
        exactValue: 1 / 3,
      },
      'Trapezoidal Rule',
      0.34375,
    ],
    [
      '/api/v1/solve/integration/simpson-13',
      {
        equation: 'x^2',
        lowerBound: 0,
        upperBound: 1,
        subintervals: 4,
        exactValue: 1 / 3,
      },
      "Simpson's 1/3 Rule",
      1 / 3,
    ],
    [
      '/api/v1/solve/integration/simpson-38',
      {
        equation: 'x^2',
        lowerBound: 0,
        upperBound: 1,
        subintervals: 3,
        exactValue: 1 / 3,
      },
      "Simpson's 3/8 Rule",
      1 / 3,
    ],
    [
      '/api/v1/solve/integration/gauss-legendre',
      {
        equation: 'x^2',
        lowerBound: 0,
        upperBound: 1,
        points: 3,
        exactValue: 1 / 3,
      },
      'Gauss-Legendre Quadrature',
      1 / 3,
    ],
  ])('POST %s returns a structured integration result', async (path, requestBody, methodName, integral) => {
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
    expect(body.data.finalAnswer.integral).toBeCloseTo(integral, 10);
    expect(body.data.finalAnswer.errorAvailable).toBe(true);
    expect(body.data.iterations.length).toBeGreaterThan(0);
    expect(body.data.graphData).toHaveLength(81);
  });

  test.each([
    [
      'missing bounds',
      '/api/v1/solve/integration/trapezoidal',
      {
        equation: 'x^2',
        subintervals: 4,
      },
    ],
    [
      'reversed bounds',
      '/api/v1/solve/integration/trapezoidal',
      {
        equation: 'x^2',
        lowerBound: 1,
        upperBound: 0,
        subintervals: 4,
      },
    ],
    [
      'missing subintervals',
      '/api/v1/solve/integration/trapezoidal',
      {
        equation: 'x^2',
        lowerBound: 0,
        upperBound: 1,
      },
    ],
    [
      'odd Simpson 1/3 subintervals',
      '/api/v1/solve/integration/simpson-13',
      {
        equation: 'x^2',
        lowerBound: 0,
        upperBound: 1,
        subintervals: 3,
      },
    ],
    [
      'Simpson 3/8 subintervals not divisible by 3',
      '/api/v1/solve/integration/simpson-38',
      {
        equation: 'x^2',
        lowerBound: 0,
        upperBound: 1,
        subintervals: 4,
      },
    ],
    [
      'unsupported Gauss point count',
      '/api/v1/solve/integration/gauss-legendre',
      {
        equation: 'x^2',
        lowerBound: 0,
        upperBound: 1,
        points: 6,
      },
    ],
  ])('POST integration endpoint validates %s', async (_name, path, requestBody) => {
    const response = await fetch(`${baseUrl}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
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

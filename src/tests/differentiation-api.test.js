'use strict';

describe('Differentiation API', () => {
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
      '/api/v1/solve/differentiation/forward',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 4 },
          { x: 2, y: 9 },
        ],
        targetX: 1,
        exactDerivative: 4,
      },
      'Forward Difference',
      5,
    ],
    [
      '/api/v1/solve/differentiation/backward',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 4 },
          { x: 2, y: 9 },
        ],
        targetX: 1,
        exactDerivative: 4,
      },
      'Backward Difference',
      3,
    ],
    [
      '/api/v1/solve/differentiation/central',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 4 },
          { x: 2, y: 9 },
        ],
        targetX: 1,
        exactDerivative: 4,
      },
      'Central Difference',
      4,
    ],
    [
      '/api/v1/solve/differentiation/lagrange',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 4 },
          { x: 3, y: 16 },
        ],
        targetX: 1,
        exactDerivative: 4,
      },
      'Lagrange Differentiation',
      4,
    ],
    [
      '/api/v1/solve/differentiation/function-finite-difference',
      {
        equation: 'x^2 + 2*x + 1',
        targetX: 1,
        h: 0.001,
        variant: 'central',
        exactDerivative: 4,
      },
      'Function-based Finite Difference',
      4,
    ],
  ])('POST %s returns a structured differentiation result', async (path, requestBody, methodName, derivative) => {
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
    expect(body.data.finalAnswer.derivative).toBeCloseTo(derivative, 6);
    expect(body.data.finalAnswer.errorAvailable).toBe(true);
    expect(body.data.iterations.length).toBeGreaterThan(0);
  });

  test('Function-based Finite Difference defaults variant to central', async () => {
    const response = await fetch(`${baseUrl}/api/v1/solve/differentiation/function-finite-difference`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        equation: 'x^2 + 2*x + 1',
        targetX: 1,
        h: 0.001,
        includeGraphData: false,
      }),
    });
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.input.variant).toBe('central');
    expect(body.data.graphData).toEqual([]);
  });

  test.each([
    [
      'duplicate points',
      '/api/v1/solve/differentiation/forward',
      {
        points: [
          { x: 0, y: 1 },
          { x: 0, y: 2 },
        ],
        targetX: 0,
      },
    ],
    [
      'unequal spacing',
      '/api/v1/solve/differentiation/forward',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 4 },
          { x: 3, y: 16 },
        ],
        targetX: 1,
      },
    ],
    [
      'missing forward neighbor',
      '/api/v1/solve/differentiation/forward',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 4 },
        ],
        targetX: 1,
      },
    ],
    [
      'missing central neighbor',
      '/api/v1/solve/differentiation/central',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 4 },
        ],
        targetX: 1,
      },
    ],
    [
      'invalid function variant',
      '/api/v1/solve/differentiation/function-finite-difference',
      {
        equation: 'x^2',
        targetX: 1,
        h: 0.001,
        variant: 'five-point',
      },
    ],
    [
      'missing h',
      '/api/v1/solve/differentiation/function-finite-difference',
      {
        equation: 'x^2',
        targetX: 1,
      },
    ],
  ])('POST differentiation endpoint validates %s', async (_name, path, requestBody) => {
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

  test('POST function-based endpoint rejects invalid expressions', async () => {
    const response = await fetch(`${baseUrl}/api/v1/solve/differentiation/function-finite-difference`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        equation: 'x^2 +',
        targetX: 1,
        h: 0.001,
      }),
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('INVALID_EXPRESSION');
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

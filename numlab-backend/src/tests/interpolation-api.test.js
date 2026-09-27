'use strict';

describe('Interpolation API', () => {
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
      '/api/v1/solve/interpolation/lagrange',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 3 },
          { x: 2, y: 2 },
        ],
        targetX: 1.5,
      },
      'Lagrange Interpolation',
      2.875,
    ],
    [
      '/api/v1/solve/interpolation/newton-divided-difference',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 3 },
          { x: 2, y: 2 },
          { x: 3, y: 5 },
        ],
        targetX: 1.5,
      },
      'Newton Divided Difference',
      2.4375,
    ],
    [
      '/api/v1/solve/interpolation/newton-forward',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 2 },
          { x: 2, y: 5 },
          { x: 3, y: 10 },
        ],
        targetX: 0.5,
      },
      'Newton Forward Interpolation',
      1.25,
    ],
    [
      '/api/v1/solve/interpolation/newton-backward',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 2 },
          { x: 2, y: 5 },
          { x: 3, y: 10 },
        ],
        targetX: 2.5,
      },
      'Newton Backward Interpolation',
      7.25,
    ],
    [
      '/api/v1/solve/interpolation/central-difference',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 2 },
          { x: 2, y: 5 },
          { x: 3, y: 10 },
          { x: 4, y: 17 },
        ],
        targetX: 2.25,
        variant: 'gauss-forward',
      },
      'Central Difference Interpolation',
      6.0625,
    ],
    [
      '/api/v1/solve/interpolation/natural-cubic-spline',
      {
        points: [
          { x: 0, y: 0 },
          { x: 1, y: 1 },
          { x: 2, y: 0 },
          { x: 3, y: 1 },
        ],
        targetX: 1.5,
      },
      'Natural Cubic Spline',
      0.5,
    ],
    [
      '/api/v1/solve/interpolation/quadratic',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 4 },
          { x: 2, y: 9 },
          { x: 3, y: 16 },
        ],
        targetX: 1.5,
      },
      'Quadratic Interpolation',
      6.25,
    ],
  ])('POST %s returns a structured interpolation result', async (path, requestBody, methodName, predictedY) => {
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
    expect(body.data.finalAnswer.predictedY).toBeCloseTo(predictedY, 6);
    expect(body.data.graphData.originalPoints.length).toBeGreaterThan(0);
    expect(body.data.graphData.sampledCurve.length).toBe(81);
    expect(body.data.graphData.predictedPoint).toHaveProperty('x', requestBody.targetX);
  });

  test.each([
    [
      'duplicate x values',
      '/api/v1/solve/interpolation/lagrange',
      {
        points: [
          { x: 0, y: 1 },
          { x: 0, y: 2 },
        ],
        targetX: 0.5,
      },
    ],
    [
      'too few cubic spline points',
      '/api/v1/solve/interpolation/natural-cubic-spline',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 2 },
        ],
        targetX: 0.5,
      },
    ],
    [
      'too few quadratic points',
      '/api/v1/solve/interpolation/quadratic',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 2 },
        ],
        targetX: 0.5,
      },
    ],
    [
      'near-zero cubic spline interval width',
      '/api/v1/solve/interpolation/natural-cubic-spline',
      {
        points: [
          { x: 0, y: 1 },
          { x: 0.0000000000001, y: 2 },
          { x: 1, y: 3 },
        ],
        targetX: 0.5,
      },
    ],
    [
      'unequally spaced finite-difference points',
      '/api/v1/solve/interpolation/newton-forward',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 2 },
          { x: 3, y: 10 },
        ],
        targetX: 0.5,
      },
    ],
    [
      'invalid central difference variant',
      '/api/v1/solve/interpolation/central-difference',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 2 },
          { x: 2, y: 5 },
        ],
        targetX: 1,
        variant: 'bad-variant',
      },
    ],
    [
      'missing targetX',
      '/api/v1/solve/interpolation/lagrange',
      {
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 2 },
        ],
      },
    ],
    [
      'non-numeric point values',
      '/api/v1/solve/interpolation/lagrange',
      {
        points: [
          { x: 0, y: 1 },
          { x: 'bad', y: 2 },
        ],
        targetX: 0.5,
      },
    ],
  ])('POST interpolation endpoint validates %s', async (_name, path, requestBody) => {
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

  test('POST central difference rejects unsuitable Bessel targetX', async () => {
    const response = await fetch(`${baseUrl}/api/v1/solve/interpolation/central-difference`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        points: [
          { x: 0, y: 1 },
          { x: 1, y: 2 },
          { x: 2, y: 5 },
          { x: 3, y: 10 },
          { x: 4, y: 17 },
        ],
        targetX: 1,
        variant: 'bessel',
      }),
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('SOLVER_PRECONDITION_FAILED');
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

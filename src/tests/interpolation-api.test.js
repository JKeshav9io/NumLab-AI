'use strict';

describe('Interpolation API', () => {
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
      expect(body.data.finalAnswer.predictedY).toBeCloseTo(predictedY, 6);
      expect(body.data.graphData.originalPoints.length).toBeGreaterThan(0);
      expect(body.data.graphData.sampledCurve.length).toBe(81);
      expect(body.data.graphData.predictedPoint).toHaveProperty('x', requestBody.targetX);
    } finally {
      await closeServer(server);
    }
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
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
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

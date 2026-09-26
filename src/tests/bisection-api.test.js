'use strict';

describe('Bisection API', () => {
  test('POST /api/v1/solve/root/bisection returns a structured solver result', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/solve/root/bisection`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          equation: 'x^3 - x - 2',
          lowerBound: 1,
          upperBound: 2,
          tolerance: 0.0001,
          maxIterations: 100,
        }),
      });
      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.meta.requestId).toBeTruthy();
      expect(body.data.method).toBe('Bisection Method');
      expect(body.data.status).toBe('converged');
      expect(body.data.finalAnswer.root).toBeCloseTo(1.5214, 3);
      expect(body.data.iterations.length).toBeGreaterThan(0);
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/solve/root/bisection returns validation errors', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/solve/root/bisection`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          equation: '',
          lowerBound: 2,
          upperBound: 1,
        }),
      });
      const body = await response.json();

      expect(response.status).toBe(400);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('VALIDATION_ERROR');
      expect(body.error.details.fields.length).toBeGreaterThan(0);
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/solve/root/bisection returns invalid JSON errors', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/solve/root/bisection`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{ "equation": "x^3 - x - 2", ',
      });
      const body = await response.json();

      expect(response.status).toBe(400);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('INVALID_JSON');
    } finally {
      await closeServer(server);
    }
  });
});

async function startApp() {
  jest.resetModules();
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


'use strict';

const matrix = [
  [10, -1, 2],
  [-1, 11, -1],
  [2, -1, 10],
];
const constants = [6, 25, -11];

describe('Linear algebra API', () => {
  test.each([
    [
      '/api/v1/solve/linear/gauss-elimination',
      { matrix, constants },
      'Gauss Elimination',
    ],
    [
      '/api/v1/solve/linear/jacobi',
      {
        matrix,
        constants,
        initialGuess: [0, 0, 0],
        tolerance: 0.0001,
        maxIterations: 100,
      },
      'Jacobi Method',
    ],
    [
      '/api/v1/solve/linear/gauss-seidel',
      {
        matrix,
        constants,
        initialGuess: [0, 0, 0],
        tolerance: 0.0001,
        maxIterations: 100,
      },
      'Gauss-Seidel Method',
    ],
  ])('POST %s returns a structured solution', async (path, requestBody, methodName) => {
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
      expect(body.data.finalAnswer.solution).toHaveLength(3);
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/solve/linear/gauss-elimination validates matrix dimensions', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/solve/linear/gauss-elimination`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          matrix: [
            [1, 2],
            [3],
          ],
          constants: [1, 2],
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

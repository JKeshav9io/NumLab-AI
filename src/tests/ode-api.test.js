'use strict';

describe('ODE API', () => {
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
      '/api/v1/solve/ode/euler',
      'Euler Method',
      3.1874849202,
    ],
    [
      '/api/v1/solve/ode/heun',
      'Heun / Improved Euler Method',
      3.4281616932,
    ],
    [
      '/api/v1/solve/ode/rk4',
      'RK4 Method',
      3.4365594883,
    ],
    [
      '/api/v1/solve/ode/milne',
      'Milne Predictor-Corrector Method',
      3.4365630324,
    ],
  ])('POST %s returns a structured ODE result', async (path, methodName, expectedY) => {
    const response = await fetch(`${baseUrl}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        equation: 'x + y',
        x0: 0,
        y0: 1,
        h: 0.1,
        xn: 1,
      }),
    });
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.method).toBe(methodName);
    expect(body.data.status).toBe('converged');
    expect(body.data.finalAnswer.y).toBeCloseTo(expectedY, 8);
    expect(body.data.iterations.length).toBeGreaterThan(0);
    expect(body.data.graphData).toHaveLength(11);
  });

  test('POST /api/v1/solve/ode/rk4 accepts steps instead of xn', async () => {
    const response = await fetch(`${baseUrl}/api/v1/solve/ode/rk4`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        equation: 'x + y',
        x0: 0,
        y0: 1,
        h: 0.1,
        steps: 10,
        includeGraphData: false,
      }),
    });
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.finalAnswer.stepsUsed).toBe(10);
    expect(body.data.graphData).toEqual([]);
  });

  test.each([
    [
      'missing xn and steps',
      {
        equation: 'x + y',
        x0: 0,
        y0: 1,
        h: 0.1,
      },
    ],
    [
      'both xn and steps',
      {
        equation: 'x + y',
        x0: 0,
        y0: 1,
        h: 0.1,
        xn: 1,
        steps: 10,
      },
    ],
    [
      'xn not greater than x0',
      {
        equation: 'x + y',
        x0: 1,
        y0: 1,
        h: 0.1,
        xn: 1,
      },
    ],
    [
      'xn not an exact step multiple',
      {
        equation: 'x + y',
        x0: 0,
        y0: 1,
        h: 0.3,
        xn: 1,
      },
    ],
    [
      'Milne too few steps',
      {
        equation: 'x + y',
        x0: 0,
        y0: 1,
        h: 0.1,
        steps: 3,
      },
      '/api/v1/solve/ode/milne',
    ],
  ])('POST ODE endpoint validates %s', async (_name, requestBody, path = '/api/v1/solve/ode/euler') => {
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

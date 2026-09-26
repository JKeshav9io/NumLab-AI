'use strict';

const createApp = require('../app');
const { prisma } = require('../db');
const solverRunRepository = require('../db/repositories/solverRunRepository');

describe('Solver Run Persistence & History API', () => {
  let server;
  let baseUrl;

  let userA = null;
  let tokenA = null;
  let userB = null;
  let tokenB = null;

  let userARunId = null;
  let userBRunId = null;

  beforeAll(async () => {
    const app = createApp();
    server = app.listen(0);
    const { port } = server.address();
    baseUrl = `http://127.0.0.1:${port}`;

    // Register User A
    const resA = await fetch(`${baseUrl}/api/v1/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: `usera_${Date.now()}@example.com`,
        password: 'Password123',
      }),
    });
    const bodyA = await resA.json();
    userA = bodyA.data.user;
    tokenA = bodyA.data.tokens.accessToken;

    // Register User B
    const resB = await fetch(`${baseUrl}/api/v1/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: `userb_${Date.now()}@example.com`,
        password: 'Password123',
      }),
    });
    const bodyB = await resB.json();
    userB = bodyB.data.user;
    tokenB = bodyB.data.tokens.accessToken;
  });

  afterAll(async () => {
    try {
      // Clean up test users and associated cascade data
      if (userA?.id) {
        await prisma.solverRun.deleteMany({ where: { userId: userA.id } });
        await prisma.user.deleteMany({ where: { id: userA.id } });
      }
      if (userB?.id) {
        await prisma.solverRun.deleteMany({ where: { userId: userB.id } });
        await prisma.user.deleteMany({ where: { id: userB.id } });
      }
    } catch (_err) {
      // Ignore cleanup error
    } finally {
      await prisma.$disconnect();
      await new Promise((resolve) => server.close(resolve));
    }
  });

  test('Anonymous solve succeeds and persists SolverRun with userId: null', async () => {
    const res = await fetch(`${baseUrl}/api/v1/solve/root/bisection`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        equation: 'x^2 - 4',
        lowerBound: 0,
        upperBound: 3,
        tolerance: 0.001,
      }),
    });
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.status).toBe('converged');
    expect(body.data.finalAnswer.root).toBeCloseTo(2, 2);

    // Give asynchronous non-blocking persistence a brief moment to write
    await new Promise((resolve) => setTimeout(resolve, 300));

    const latestAnonRun = await prisma.solverRun.findFirst({
      where: {
        userId: null,
        method: 'root/bisection',
      },
      orderBy: { createdAt: 'desc' },
    });

    expect(latestAnonRun).toBeDefined();
    expect(latestAnonRun.userId).toBeNull();
    expect(latestAnonRun.inputPayload.equation).toBe('x^2 - 4');
  });

  test('Authenticated solve succeeds and attributes SolverRun to userA', async () => {
    const res = await fetch(`${baseUrl}/api/v1/solve/root/bisection`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        equation: 'x^2 - 9',
        lowerBound: 0,
        upperBound: 4,
        tolerance: 0.001,
      }),
    });
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.finalAnswer.root).toBeCloseTo(3, 2);

    // Give asynchronous persistence a moment
    await new Promise((resolve) => setTimeout(resolve, 300));

    const userRuns = await prisma.solverRun.findMany({
      where: { userId: userA.id },
      orderBy: { createdAt: 'desc' },
    });

    expect(userRuns.length).toBeGreaterThanOrEqual(1);
    expect(userRuns[0].userId).toBe(userA.id);
    expect(userRuns[0].inputPayload.equation).toBe('x^2 - 9');
    userARunId = userRuns[0].id;
  });

  test('Authenticated solve attributes SolverRun to userB', async () => {
    const res = await fetch(`${baseUrl}/api/v1/solve/root/newton`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({
        equation: 'x^2 - 16',
        initialGuess: 5,
        tolerance: 0.001,
      }),
    });
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.finalAnswer.root).toBeCloseTo(4, 2);

    await new Promise((resolve) => setTimeout(resolve, 300));

    const userBRuns = await prisma.solverRun.findMany({
      where: { userId: userB.id },
      orderBy: { createdAt: 'desc' },
    });

    expect(userBRuns.length).toBeGreaterThanOrEqual(1);
    expect(userBRuns[0].userId).toBe(userB.id);
    userBRunId = userBRuns[0].id;
  });

  test('GET /api/v1/users/me/history returns only authenticated user runs with pagination', async () => {
    const res = await fetch(`${baseUrl}/api/v1/users/me/history?limit=10&offset=0`, {
      headers: {
        Authorization: `Bearer ${tokenA}`,
      },
    });
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(Array.isArray(body.data.runs)).toBe(true);
    expect(body.data.pagination).toBeDefined();
    expect(body.data.pagination.total).toBeGreaterThanOrEqual(1);
    expect(body.data.pagination.limit).toBe(10);
    expect(body.data.pagination.offset).toBe(0);

    // Verify all returned runs belong strictly to userA
    body.data.runs.forEach((run) => {
      expect(run.userId).toBe(userA.id);
    });

    // Ensure user B's run is NOT in user A's history
    const containsUserBRun = body.data.runs.some((r) => r.id === userBRunId);
    expect(containsUserBRun).toBe(false);
  });

  test('GET /api/v1/users/me/history/:runId returns user own run', async () => {
    const res = await fetch(`${baseUrl}/api/v1/users/me/history/${userARunId}`, {
      headers: {
        Authorization: `Bearer ${tokenA}`,
      },
    });
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.run.id).toBe(userARunId);
    expect(body.data.run.userId).toBe(userA.id);
    expect(body.data.run.inputPayload.equation).toBe('x^2 - 9');
  });

  test('GET /api/v1/users/me/history/:runId returns 404 (not 403) when fetching another user run', async () => {
    // User A tries to access User B's run
    const res = await fetch(`${baseUrl}/api/v1/users/me/history/${userBRunId}`, {
      headers: {
        Authorization: `Bearer ${tokenA}`,
      },
    });
    const body = await res.json();

    expect(res.status).toBe(404);
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('NOT_FOUND');
    expect(body.error.message).toBe('Solver run not found');
  });

  test('History endpoints return 401 UNAUTHORIZED without a valid Bearer token', async () => {
    // 1. /me/history without auth
    const resList = await fetch(`${baseUrl}/api/v1/users/me/history`);
    const bodyList = await resList.json();
    expect(resList.status).toBe(401);
    expect(bodyList.success).toBe(false);
    expect(bodyList.error.code).toBe('UNAUTHORIZED');

    // 2. /me/history/:runId without auth
    const resDetail = await fetch(`${baseUrl}/api/v1/users/me/history/${userARunId}`);
    const bodyDetail = await resDetail.json();
    expect(resDetail.status).toBe(401);
    expect(bodyDetail.success).toBe(false);
    expect(bodyDetail.error.code).toBe('UNAUTHORIZED');
  });

  test('Non-blocking DB write failure does not fail the user-facing solver response', async () => {
    const spy = jest.spyOn(solverRunRepository, 'create').mockRejectedValueOnce(
      new Error('Simulated Database Outage')
    );

    const res = await fetch(`${baseUrl}/api/v1/solve/root/bisection`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        equation: 'x^2 - 4',
        lowerBound: 0,
        upperBound: 3,
        tolerance: 0.001,
      }),
    });
    const body = await res.json();

    // The user MUST still receive 200 OK with correct math results
    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.status).toBe('converged');
    expect(body.data.finalAnswer.root).toBeCloseTo(2, 2);

    spy.mockRestore();
  });
});

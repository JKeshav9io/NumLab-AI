'use strict';

const { prisma } = require('../db');
const userRepository = require('../db/repositories/userRepository');
const solverRunRepository = require('../db/repositories/solverRunRepository');
const aiExplanationRepository = require('../db/repositories/aiExplanationRepository');
const tokenService = require('../modules/auth/token');

describe('Reports API (PDF Lab Report Generation)', () => {
  let userA;
  let userB;
  let userAToken;
  let userBToken;
  let runUserAWithAi;
  let runUserAWithoutAi;
  let runUserB;

  beforeAll(async () => {
    // 1. Create test users
    userA = await userRepository.createUser({
      email: `report-user-a-${Date.now()}@example.com`,
      passwordHash: 'dummy-hash-a',
    });
    userB = await userRepository.createUser({
      email: `report-user-b-${Date.now()}@example.com`,
      passwordHash: 'dummy-hash-b',
    });

    userAToken = tokenService.generateAccessToken(userA.id);
    userBToken = tokenService.generateAccessToken(userB.id);

    // 2. Create solver runs
    runUserAWithAi = await solverRunRepository.create({
      userId: userA.id,
      method: 'root/bisection',
      inputPayload: {
        equation: 'x^3 - x - 2',
        lowerBound: 1,
        upperBound: 2,
        tolerance: 0.0001,
      },
      outputPayload: {
        method: 'Bisection Method',
        status: 'converged',
        executionTimeMs: 3,
        finalAnswer: { root: 1.5214, converged: true },
        iterations: [
          { iteration: 1, a: 1, b: 2, c: 1.5, fC: -0.125, error: 0.5 },
          { iteration: 2, a: 1.5, b: 2, c: 1.75, fC: 1.609, error: 0.25 },
        ],
        graphData: [
          { x: 1, y: -2 },
          { x: 1.5, y: -0.125 },
          { x: 2, y: 4 },
        ],
        warnings: [],
      },
    });

    // Attach an AI explanation to runUserAWithAi
    await aiExplanationRepository.create({
      solverRunId: runUserAWithAi.id,
      focusMode: 'steps',
      promptHash: `hash-report-test-${Date.now()}`,
      responseText: 'The bisection method successfully halved the interval to isolate the root.',
    });

    runUserAWithoutAi = await solverRunRepository.create({
      userId: userA.id,
      method: 'ode/euler',
      inputPayload: {
        equation: 'x + y',
        x0: 0,
        y0: 1,
        h: 0.1,
        steps: 5,
      },
      outputPayload: {
        method: 'Euler Method',
        status: 'converged',
        executionTimeMs: 1,
        finalAnswer: { y: 1.61051, x: 0.5, converged: true },
        iterations: [
          { step: 1, x: 0, y: 1, nextY: 1.1 },
          { step: 2, x: 0.1, y: 1.1, nextY: 1.22 },
        ],
        graphData: [
          { x: 0, y: 1 },
          { x: 0.1, y: 1.1 },
          { x: 0.2, y: 1.22 },
        ],
        warnings: [],
      },
    });

    runUserB = await solverRunRepository.create({
      userId: userB.id,
      method: 'linear/gauss-elimination',
      inputPayload: {
        matrix: [[2, 1], [1, 3]],
        constants: [5, 5],
      },
      outputPayload: {
        method: 'Gauss Elimination',
        status: 'converged',
        executionTimeMs: 1,
        finalAnswer: { solution: [2, 1], converged: true },
        iterations: [],
        warnings: [],
      },
    });
  });

  afterAll(async () => {
    // Cleanup created test records
    await prisma.aiExplanation.deleteMany({
      where: { solverRunId: { in: [runUserAWithAi.id, runUserAWithoutAi.id, runUserB.id] } },
    });
    await prisma.solverRun.deleteMany({
      where: { id: { in: [runUserAWithAi.id, runUserAWithoutAi.id, runUserB.id] } },
    });
    await prisma.user.deleteMany({
      where: { id: { in: [userA.id, userB.id] } },
    });
    await prisma.$disconnect();
  });

  test('POST /api/v1/reports/:runId generates a valid PDF report for authenticated owner', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/reports/${runUserAWithAi.id}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${userAToken}`,
        },
      });

      expect(response.status).toBe(200);
      expect(response.headers.get('content-type')).toBe('application/pdf');
      expect(response.headers.get('content-disposition')).toContain('attachment');
      expect(response.headers.get('content-disposition')).toContain('numlab-report-root-bisection');

      const arrayBuffer = await response.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);

      // Verify PDF magic header bytes "%PDF-"
      expect(buffer.length).toBeGreaterThan(1000);
      const magicBytes = buffer.subarray(0, 5).toString('ascii');
      expect(magicBytes).toBe('%PDF-');
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/reports/:runId succeeds when run has no attached AI explanation', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/reports/${runUserAWithoutAi.id}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${userAToken}`,
        },
      });

      expect(response.status).toBe(200);
      expect(response.headers.get('content-type')).toBe('application/pdf');

      const arrayBuffer = await response.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);
      expect(buffer.subarray(0, 5).toString('ascii')).toBe('%PDF-');
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/reports/:runId returns 404 NOT_FOUND for run belonging to another user', async () => {
    const { server, baseUrl } = await startApp();

    try {
      // User A attempts to generate a report for User B's solver run
      const response = await fetch(`${baseUrl}/api/v1/reports/${runUserB.id}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${userAToken}`,
        },
      });

      const body = await response.json();
      expect(response.status).toBe(404);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('NOT_FOUND');
      expect(body.error.message).toBe('Solver run not found');
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/reports/:runId returns 404 NOT_FOUND for non-existent runId', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const nonExistentId = '00000000-0000-0000-0000-000000000000';
      const response = await fetch(`${baseUrl}/api/v1/reports/${nonExistentId}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${userAToken}`,
        },
      });

      const body = await response.json();
      expect(response.status).toBe(404);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('NOT_FOUND');
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/reports/:runId returns 401 UNAUTHORIZED when no token is provided', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/reports/${runUserAWithAi.id}`, {
        method: 'POST',
      });

      const body = await response.json();
      expect(response.status).toBe(401);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('UNAUTHORIZED');
    } finally {
      await closeServer(server);
    }
  });

  test('POST /api/v1/reports/:runId returns 400 VALIDATION_ERROR for invalid UUID', async () => {
    const { server, baseUrl } = await startApp();

    try {
      const response = await fetch(`${baseUrl}/api/v1/reports/not-a-valid-uuid`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${userAToken}`,
        },
      });

      const body = await response.json();
      expect(response.status).toBe(400);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    } finally {
      await closeServer(server);
    }
  });

  test('regression: reportLimiter keys by authenticated userId, not IP (independent quotas per user on same IP)', async () => {
    const { createReportLimiter } = require('../common/middleware/rateLimiter');
    // Configure rate limiter with quota of 2 reports per window for testing
    const testLimiter = createReportLimiter({ limit: 2 });
    const { server, baseUrl } = await startApp({ reportLimiter: testLimiter });

    try {
      // User A makes 2 requests (exhausts User A's quota) from the client IP (127.0.0.1)
      const resA1 = await fetch(`${baseUrl}/api/v1/reports/${runUserAWithoutAi.id}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${userAToken}` },
      });
      expect(resA1.status).toBe(200);

      const resA2 = await fetch(`${baseUrl}/api/v1/reports/${runUserAWithoutAi.id}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${userAToken}` },
      });
      expect(resA2.status).toBe(200);

      // User A's 3rd request is blocked with 429
      const resA3 = await fetch(`${baseUrl}/api/v1/reports/${runUserAWithoutAi.id}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${userAToken}` },
      });
      expect(resA3.status).toBe(429);
      const bodyA3 = await resA3.json();
      expect(bodyA3.error.code).toBe('RATE_LIMIT_EXCEEDED');

      // User B makes a request from the EXACT SAME client IP (127.0.0.1).
      // If reportLimiter were keyed by IP (the bug), User B would be blocked with 429.
      // Because authenticate runs before reportLimiter and keys by req.user.id, User B succeeds.
      const resB1 = await fetch(`${baseUrl}/api/v1/reports/${runUserB.id}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${userBToken}` },
      });
      expect(resB1.status).toBe(200);

      const resB2 = await fetch(`${baseUrl}/api/v1/reports/${runUserB.id}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${userBToken}` },
      });
      expect(resB2.status).toBe(200);

      // User B's 3rd request hits their own quota limit
      const resB3 = await fetch(`${baseUrl}/api/v1/reports/${runUserB.id}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${userBToken}` },
      });
      expect(resB3.status).toBe(429);

      // User A is still blocked
      const resA4 = await fetch(`${baseUrl}/api/v1/reports/${runUserAWithoutAi.id}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${userAToken}` },
      });
      expect(resA4.status).toBe(429);
    } finally {
      await closeServer(server);
    }
  });
});

async function startApp(options = {}) {
  const createApp = require('../app');
  const app = createApp(options);
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

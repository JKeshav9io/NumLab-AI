'use strict';

const { prisma, healthCheck } = require('../db');
const userRepository = require('../db/repositories/userRepository');
const solverRunRepository = require('../db/repositories/solverRunRepository');
const aiExplanationRepository = require('../db/repositories/aiExplanationRepository');

describe('Phase 3 query contracts', () => {
  afterEach(() => jest.restoreAllMocks());

  test('history persists a bounded summary and lists no full payloads', async () => {
    const insert = jest.spyOn(prisma.solverRun, 'create').mockResolvedValue({ id: 'run' });
    const list = jest.spyOn(prisma.solverRun, 'findMany').mockResolvedValue([]);
    jest.spyOn(prisma.solverRun, 'count').mockResolvedValue(0);
    await solverRunRepository.create({
      method: 'root/bisection', inputPayload: { equation: 'x'.repeat(500) },
      outputPayload: { method: 'Bisection', status: 'converged', graphData: [1, 2, 3] },
    });
    expect(insert.mock.calls[0][0].data.summaryPayload).toEqual({
      method: 'Bisection', status: 'converged', equation: 'x'.repeat(120),
    });
    await solverRunRepository.findByUserId('user');
    expect(list.mock.calls[0][0].select).toEqual({
      id: true, method: true, summaryPayload: true, createdAt: true,
    });
  });


});

describe('Database & Repository Layer Integration', () => {
  const testEmail = `test_${Date.now()}@example.com`;
  let testUserId = null;
  let testSolverRunId = null;
  let testExplanationId = null;
  const testPromptHash = `hash_${Date.now()}`;

  afterAll(async () => {
    // Clean up created test data
    try {
      if (testExplanationId) {
        await prisma.aiExplanation.deleteMany({
          where: { id: testExplanationId },
        });
      }
      if (testSolverRunId) {
        await prisma.solverRun.deleteMany({
          where: { id: testSolverRunId },
        });
      }
      if (testUserId) {
        await prisma.user.deleteMany({
          where: { id: testUserId },
        });
      }
    } finally {
      await prisma.$disconnect();
    }
  });

  test('healthCheck returns healthy status when database is reachable', async () => {
    const health = await healthCheck();
    expect(health.status).toBe('healthy');
    expect(health.database).toBe('connected');
  });

  test('userRepository creates, queries, and soft-deletes a user', async () => {
    // 1. Create User
    const user = await userRepository.createUser({
      email: testEmail,
      passwordHash: 'dummy_hashed_password_for_testing',
    });

    expect(user).toBeDefined();
    expect(user.id).toBeDefined();
    expect(user.email).toBe(testEmail);
    expect(user.deletedAt).toBeNull();
    testUserId = user.id;

    // 2. Find by email
    const byEmail = await userRepository.findByEmail(testEmail);
    expect(byEmail).toBeDefined();
    expect(byEmail.id).toBe(testUserId);

    // 3. Find by ID
    const byId = await userRepository.findById(testUserId);
    expect(byId).toBeDefined();
    expect(byId.email).toBe(testEmail);

    // 4. Soft delete
    const deleted = await userRepository.softDeleteUser(testUserId);
    expect(deleted.deletedAt).not.toBeNull();

    // 5. Query after soft-delete should return null
    const afterDelete = await userRepository.findById(testUserId);
    expect(afterDelete).toBeNull();
  });

  test('solverRunRepository creates and queries solver run records', async () => {
    const run = await solverRunRepository.create({
      userId: testUserId,
      method: 'root/bisection',
      inputPayload: { equation: 'x^2 - 4', lowerBound: 0, upperBound: 3 },
      outputPayload: { status: 'converged', finalAnswer: { root: 2 } },
    });

    expect(run).toBeDefined();
    expect(run.id).toBeDefined();
    expect(run.method).toBe('root/bisection');
    expect(run.inputPayload.equation).toBe('x^2 - 4');
    testSolverRunId = run.id;

    const fetched = await solverRunRepository.findById(run.id);
    expect(fetched).toBeDefined();
    expect(fetched.id).toBe(run.id);
    expect(fetched.aiExplanations).toEqual([]);

    const userRuns = await solverRunRepository.findByUserId(testUserId);
    expect(userRuns.total).toBeGreaterThanOrEqual(1);
    expect(userRuns.runs.some((r) => r.id === run.id)).toBe(true);
  });

  test('aiExplanationRepository creates and finds explanations by promptHash', async () => {
    const explanation = await aiExplanationRepository.create({
      solverRunId: testSolverRunId,
      focusMode: 'steps',
      promptHash: testPromptHash,
      responseText: 'The bisection method converged to the root 2 in 14 steps.',
      expiresAt: new Date(Date.now() + 86400000), // 24h in future
    });

    expect(explanation).toBeDefined();
    expect(explanation.id).toBeDefined();
    expect(explanation.promptHash).toBe(testPromptHash);
    testExplanationId = explanation.id;

    const cached = await aiExplanationRepository.findByPromptHash(testPromptHash);
    expect(cached).toBeDefined();
    expect(cached.id).toBe(explanation.id);
    expect(cached.responseText).toBe(explanation.responseText);
  });

  test('history pages break identical creation timestamps by descending run ID', async () => {
    const ids = [require('crypto').randomUUID(), require('crypto').randomUUID()].sort();
    try {
      for (const id of ids) {
        await prisma.solverRun.create({ data: {
          id, userId: testUserId, method: 'root/bisection',
          inputPayload: {}, outputPayload: {}, createdAt: new Date('2100-01-01'),
        } });
      }
      const first = await solverRunRepository.findByUserId(testUserId, { limit: 1 });
      const next = await solverRunRepository.findByUserId(testUserId, { limit: 1, offset: 1 });
      expect([first.runs[0].id, next.runs[0].id]).toEqual([...ids].reverse());
    } finally {
      await prisma.solverRun.deleteMany({ where: { id: { in: ids } } });
    }
  });
});

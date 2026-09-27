'use strict';

const crypto = require('crypto');
const { prisma, cleanupExpiredRecords } = require('../db');
const { cleanupExpiredRefreshTokens, cleanupExpiredAiExplanations } = require('../db/cleanup');
const userRepository = require('../db/repositories/userRepository');

describe('TTL cleanup for expired records', () => {
  let testUser = null;
  const testEmail = `ttl_cleanup_${Date.now()}@example.com`;

  beforeAll(async () => {
    testUser = await userRepository.createUser({
      email: testEmail,
      passwordHash: 'dummy_hash_for_ttl_test',
    });
  });

  afterAll(async () => {
    try {
      if (testUser?.id) {
        await prisma.refreshToken.deleteMany({ where: { userId: testUser.id } });
        await prisma.aiExplanation.deleteMany({ where: { userId: testUser.id } });
        await prisma.user.deleteMany({ where: { id: testUser.id } });
      }
    } catch (_err) {
      // Ignore cleanup error
    } finally {
      await prisma.$disconnect();
    }
  });

  test('removes expired records while preserving valid and persistent records', async () => {
    const past = new Date(Date.now() - 3600000); // 1 hour ago
    const future = new Date(Date.now() + 3600000); // 1 hour from now

    // 1. Create expired refresh token
    const expiredTokenHash = crypto.createHash('sha256').update(`expired_${Date.now()}`).digest('hex');
    const expiredToken = await prisma.refreshToken.create({
      data: {
        userId: testUser.id,
        tokenHash: expiredTokenHash,
        expiresAt: past,
      },
    });

    // 2. Create valid (unexpired) refresh token
    const validTokenHash = crypto.createHash('sha256').update(`valid_${Date.now()}`).digest('hex');
    const validToken = await prisma.refreshToken.create({
      data: {
        userId: testUser.id,
        tokenHash: validTokenHash,
        expiresAt: future,
      },
    });

    // 3. Create expired AI explanation
    const expiredPromptHash = crypto.createHash('sha256').update(`prompt_expired_${Date.now()}`).digest('hex');
    const expiredExplanation = await prisma.aiExplanation.create({
      data: {
        userId: testUser.id,
        promptHash: expiredPromptHash,
        responseText: 'Expired explanation text',
        expiresAt: past,
      },
    });

    // 4. Create valid (unexpired) AI explanation
    const validPromptHash = crypto.createHash('sha256').update(`prompt_valid_${Date.now()}`).digest('hex');
    const validExplanation = await prisma.aiExplanation.create({
      data: {
        userId: testUser.id,
        promptHash: validPromptHash,
        responseText: 'Valid active explanation text',
        expiresAt: future,
      },
    });

    // 5. Create persistent AI explanation (expiresAt is null)
    const persistentPromptHash = crypto.createHash('sha256').update(`prompt_persistent_${Date.now()}`).digest('hex');
    const persistentExplanation = await prisma.aiExplanation.create({
      data: {
        userId: testUser.id,
        promptHash: persistentPromptHash,
        responseText: 'Persistent explanation text',
        expiresAt: null,
      },
    });

    // Run cleanup
    const result = await cleanupExpiredRecords();

    expect(result.refreshTokensDeleted).toBeGreaterThanOrEqual(1);
    expect(result.aiExplanationsDeleted).toBeGreaterThanOrEqual(1);

    // Verify expired records were deleted
    const foundExpiredToken = await prisma.refreshToken.findUnique({ where: { id: expiredToken.id } });
    expect(foundExpiredToken).toBeNull();

    const foundExpiredExplanation = await prisma.aiExplanation.findUnique({ where: { id: expiredExplanation.id } });
    expect(foundExpiredExplanation).toBeNull();

    // Verify valid records remain untouched
    const foundValidToken = await prisma.refreshToken.findUnique({ where: { id: validToken.id } });
    expect(foundValidToken).not.toBeNull();
    expect(foundValidToken.id).toBe(validToken.id);

    const foundValidExplanation = await prisma.aiExplanation.findUnique({ where: { id: validExplanation.id } });
    expect(foundValidExplanation).not.toBeNull();
    expect(foundValidExplanation.id).toBe(validExplanation.id);

    // Verify persistent record remains untouched
    const foundPersistentExplanation = await prisma.aiExplanation.findUnique({ where: { id: persistentExplanation.id } });
    expect(foundPersistentExplanation).not.toBeNull();
    expect(foundPersistentExplanation.id).toBe(persistentExplanation.id);
  });

  test('cleanup is safe and returns numeric counts when there is nothing to delete', async () => {
    const result = await cleanupExpiredRecords();
    expect(typeof result.refreshTokensDeleted).toBe('number');
    expect(typeof result.aiExplanationsDeleted).toBe('number');
  });

  test('individual cleanup functions operate safely on empty conditions', async () => {
    const pastCutoff = new Date(Date.now() - 100000000); // long ago
    const tokensDeleted = await cleanupExpiredRefreshTokens(pastCutoff);
    expect(tokensDeleted).toBe(0);

    const explanationsDeleted = await cleanupExpiredAiExplanations(pastCutoff);
    expect(explanationsDeleted).toBe(0);
  });

  test('safely handles database failures', async () => {
    jest.spyOn(prisma.refreshToken, 'deleteMany').mockRejectedValueOnce(new Error('Simulated DB failure'));

    await expect(cleanupExpiredRefreshTokens()).rejects.toThrow();
    jest.restoreAllMocks();
  });
});

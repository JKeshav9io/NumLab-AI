'use strict';

const { prisma } = require('../db');
const { generateAccessToken, generateRefreshToken } = require('../modules/auth/token');

describe('Authentication API & Protected Routes', () => {
  let server;
  let baseUrl;
  const uniquePrefix = `auth_test_${Date.now()}`;
  const testEmail = `${uniquePrefix}@example.com`;
  const testPassword = 'Password123';
  let registeredUserId = null;
  let currentRefreshToken = null;
  let currentAccessToken = null;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    const createApp = require('../app');
    const app = createApp();
    server = app.listen(0);
    const { port } = server.address();
    baseUrl = `http://127.0.0.1:${port}`;
  });

  afterAll(async () => {
    // Clean up created test user and associated refresh tokens
    try {
      if (registeredUserId) {
        await prisma.refreshToken.deleteMany({
          where: { userId: registeredUserId },
        });
        await prisma.user.deleteMany({
          where: { id: registeredUserId },
        });
      }
    } catch (_err) {
      // Ignore cleanup error
    } finally {
      await new Promise((resolve) => server.close(resolve));
      await prisma.$disconnect();
    }
  });

  describe('POST /api/v1/auth/register', () => {
    test('successfully registers a new user and returns token pair', async () => {
      const response = await fetch(`${baseUrl}/api/v1/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: testEmail,
          password: testPassword,
        }),
      });

      const body = await response.json();

      expect(response.status).toBe(201);
      expect(body.success).toBe(true);
      expect(body.data.user).toBeDefined();
      expect(body.data.user.id).toBeDefined();
      expect(body.data.user.email).toBe(testEmail);
      expect(body.data.user.passwordHash).toBeUndefined(); // Must never expose password hash
      expect(body.data.tokens.accessToken).toBeDefined();
      expect(body.data.tokens.refreshToken).toBeDefined();
      expect(body.data.tokens.expiresIn).toBe(900);

      registeredUserId = body.data.user.id;
      currentAccessToken = body.data.tokens.accessToken;
      currentRefreshToken = body.data.tokens.refreshToken;
    });

    test('rejects duplicate email with 409 CONFLICT', async () => {
      const response = await fetch(`${baseUrl}/api/v1/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: testEmail,
          password: testPassword,
        }),
      });

      const body = await response.json();

      expect(response.status).toBe(409);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('CONFLICT');
    });

    test.each([
      ['password too short (< 8 chars)', { email: `short_${Date.now()}@test.com`, password: 'Pass1' }],
      ['password missing number', { email: `nonum_${Date.now()}@test.com`, password: 'PasswordOnly' }],
      ['invalid email format', { email: 'not-an-email', password: 'Password123' }],
    ])('validates registration input: %s', async (_name, requestBody) => {
      const response = await fetch(`${baseUrl}/api/v1/auth/register`, {
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

  describe('POST /api/v1/auth/login', () => {
    test('successfully authenticates with valid credentials', async () => {
      const response = await fetch(`${baseUrl}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: testEmail,
          password: testPassword,
        }),
      });

      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data.user.email).toBe(testEmail);
      expect(body.data.tokens.accessToken).toBeDefined();
      expect(body.data.tokens.refreshToken).toBeDefined();

      currentAccessToken = body.data.tokens.accessToken;
      currentRefreshToken = body.data.tokens.refreshToken;
    });

    test('rejects wrong password with generic INVALID_CREDENTIALS', async () => {
      const response = await fetch(`${baseUrl}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: testEmail,
          password: 'WrongPassword999',
        }),
      });

      const body = await response.json();

      expect(response.status).toBe(401);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('INVALID_CREDENTIALS');
      expect(body.error.message).toBe('Invalid email or password');
    });

    test('rejects non-existent email with identical generic INVALID_CREDENTIALS', async () => {
      const response = await fetch(`${baseUrl}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: `nonexistent_${Date.now()}@example.com`,
          password: 'Password123',
        }),
      });

      const body = await response.json();

      expect(response.status).toBe(401);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('INVALID_CREDENTIALS');
      expect(body.error.message).toBe('Invalid email or password');
    });
  });

  describe('POST /api/v1/auth/refresh (Token Rotation)', () => {
    test('rotates refresh token and returns new token pair', async () => {
      const oldRefreshToken = currentRefreshToken;

      const response = await fetch(`${baseUrl}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refreshToken: oldRefreshToken,
        }),
      });

      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data.tokens.accessToken).toBeDefined();
      expect(body.data.tokens.refreshToken).toBeDefined();
      expect(body.data.tokens.refreshToken).not.toBe(oldRefreshToken); // Must be a new token

      currentAccessToken = body.data.tokens.accessToken;
      currentRefreshToken = body.data.tokens.refreshToken;

      // Re-using the OLD refresh token must now be rejected (single-use rotation protection)
      const reuseResponse = await fetch(`${baseUrl}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refreshToken: oldRefreshToken,
        }),
      });

      const reuseBody = await reuseResponse.json();
      expect(reuseResponse.status).toBe(401);
      expect(reuseBody.error.code).toBe('TOKEN_REVOKED');
    });

    test('rejects invalid or malformed refresh token', async () => {
      const response = await fetch(`${baseUrl}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refreshToken: 'invalid.jwt.token',
        }),
      });

      const body = await response.json();

      expect(response.status).toBe(401);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('INVALID_TOKEN');
    });
  });

  describe('Protected Routes & Authorization Middleware', () => {
    test('GET /api/v1/users/me returns authenticated user profile with valid Bearer token', async () => {
      const response = await fetch(`${baseUrl}/api/v1/users/me`, {
        headers: {
          Authorization: `Bearer ${currentAccessToken}`,
        },
      });

      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data.id).toBe(registeredUserId);
      expect(body.data.email).toBe(testEmail);
      expect(body.data.passwordHash).toBeUndefined();
    });

    test('GET /api/v1/users/me rejects request without Authorization header with 401', async () => {
      const response = await fetch(`${baseUrl}/api/v1/users/me`);
      const body = await response.json();

      expect(response.status).toBe(401);
      expect(body.success).toBe(false);
      expect(body.error.code).toBe('UNAUTHORIZED');
    });

    test('GET /api/v1/users/me rejects refresh token used as access token with 401 INVALID_TOKEN', async () => {
      const response = await fetch(`${baseUrl}/api/v1/users/me`, {
        headers: {
          Authorization: `Bearer ${currentRefreshToken}`,
        },
      });

      const body = await response.json();

      expect(response.status).toBe(401);
      expect(body.error.code).toBe('INVALID_TOKEN');
    });
  });

  describe('POST /api/v1/auth/logout & /api/v1/auth/logout-all', () => {
    test('POST /api/v1/auth/logout revokes specific refresh token', async () => {
      const response = await fetch(`${baseUrl}/api/v1/auth/logout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refreshToken: currentRefreshToken,
        }),
      });

      const body = await response.json();
      expect(response.status).toBe(200);
      expect(body.success).toBe(true);

      // Refreshing with logged-out token should fail
      const refreshResponse = await fetch(`${baseUrl}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refreshToken: currentRefreshToken,
        }),
      });

      expect(refreshResponse.status).toBe(401);
    });

    test('POST /api/v1/auth/logout-all revokes all sessions for user', async () => {
      // 1. Log in again to get active tokens
      const loginRes = await fetch(`${baseUrl}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: testEmail,
          password: testPassword,
        }),
      });
      const loginBody = await loginRes.json();
      const newAccess = loginBody.data.tokens.accessToken;
      const newRefresh = loginBody.data.tokens.refreshToken;

      // 2. Call logout-all
      const logoutAllRes = await fetch(`${baseUrl}/api/v1/auth/logout-all`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${newAccess}`,
        },
      });

      const logoutAllBody = await logoutAllRes.json();
      expect(logoutAllRes.status).toBe(200);
      expect(logoutAllBody.success).toBe(true);

      // 3. Refresh should fail
      const refreshRes = await fetch(`${baseUrl}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refreshToken: newRefresh,
        }),
      });
      expect(refreshRes.status).toBe(401);
    });
  });

  describe('Public Solver Endpoints (Must Remain Unauthenticated)', () => {
    test('POST /api/v1/solve/root/bisection operates without Authorization header', async () => {
      const response = await fetch(`${baseUrl}/api/v1/solve/root/bisection`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          equation: 'x^2 - 4',
          lowerBound: 0,
          upperBound: 3,
        }),
      });

      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data.finalAnswer.root).toBeCloseTo(2, 4);
    });
  });
});

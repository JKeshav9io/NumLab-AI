'use strict';

describe('config foundation', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    const testEnv = {
      ...originalEnv,
      NODE_ENV: 'test',
      DATABASE_URL: 'postgresql://numlab_user:changeme@localhost:5432/numlab',
      JWT_SECRET: 'test-secret',
      AI_API_KEY: 'test-key',
      AI_MODEL: 'gpt-4o-mini',
      AI_BASE_URL: 'https://api.openai.com/v1',
      AI_MAX_TOKENS: '700',
      AI_TIMEOUT_MS: '15000',
    };

    process.env = testEnv;
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  test('loads validated environment config', () => {
    const env = require('../config/env');

    expect(env.NODE_ENV).toBe('test');
    expect(env.PORT).toBe(3000);
    expect(env.DATABASE_URL).toBe('postgresql://numlab_user:changeme@localhost:5432/numlab');
    expect(env.AI_MODEL).toBe('gpt-4o-mini');
    expect(env.AI_BASE_URL).toBe('https://api.openai.com/v1');
    expect(env.AI_MAX_TOKENS).toBe(700);
    expect(env.AI_TIMEOUT_MS).toBe(15000);
  });

  test('loads pino logger', () => {
    const logger = require('../config/logger');

    expect(typeof logger.info).toBe('function');
    expect(typeof logger.error).toBe('function');
  });

  test('regression: hard-fails process.exit(1) on weak JWT_SECRET in production mode', () => {
    const exitSpy = jest.spyOn(process, 'exit').mockImplementation(() => {});
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

    process.env = {
      ...process.env,
      NODE_ENV: 'production',
      PORT: '3000',
      DATABASE_URL: 'postgresql://localhost:5432/db',
      JWT_SECRET: 'weak-secret-under-32-chars',
      AI_API_KEY: 'test-key',
    };

    require('../config/env');

    expect(exitSpy).toHaveBeenCalledWith(1);
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      expect.stringContaining('FATAL SECURITY ERROR: JWT_SECRET appears to use a default placeholder or is under 32 characters')
    );

    exitSpy.mockRestore();
    consoleErrorSpy.mockRestore();
  });

  test('regression: permits strong 32+ char JWT_SECRET in production mode without exiting', () => {
    const exitSpy = jest.spyOn(process, 'exit').mockImplementation(() => {});
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

    process.env = {
      ...process.env,
      NODE_ENV: 'production',
      PORT: '3000',
      DATABASE_URL: 'postgresql://localhost:5432/db',
      JWT_SECRET: 'a-cryptographically-secure-random-secret-with-plenty-of-entropy-over-32-chars',
      AI_API_KEY: 'test-key',
    };

    const env = require('../config/env');

    expect(exitSpy).not.toHaveBeenCalled();
    expect(env.JWT_SECRET).toBe('a-cryptographically-secure-random-secret-with-plenty-of-entropy-over-32-chars');

    exitSpy.mockRestore();
    consoleErrorSpy.mockRestore();
  });
});

describe('Express app foundation', () => {
  test('GET /health returns healthy when database is reachable', async () => {
    jest.resetModules();
    process.env.NODE_ENV = 'test';

    const createApp = require('../app');
    const app = createApp();
    const server = app.listen(0);

    try {
      const { port } = server.address();
      const response = await fetch(`http://127.0.0.1:${port}/health`);
      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body).toEqual({ status: 'healthy', database: 'connected' });
    } finally {
      await new Promise((resolve, reject) => {
        server.close((err) => {
          if (err) reject(err);
          else resolve();
        });
      });
    }
  });

  test('GET /health returns 503 unhealthy when database fails', async () => {
    jest.resetModules();
    process.env.NODE_ENV = 'test';

    const db = require('../db');
    jest.spyOn(db, 'healthCheck').mockResolvedValueOnce({
      status: 'unhealthy',
      error: 'Connection terminated unexpectedly',
    });

    const createApp = require('../app');
    const app = createApp();
    const server = app.listen(0);

    try {
      const { port } = server.address();
      const response = await fetch(`http://127.0.0.1:${port}/health`);
      const body = await response.json();

      expect(response.status).toBe(503);
      expect(body).toEqual({
        status: 'unhealthy',
        error: 'Connection terminated unexpectedly',
      });
    } finally {
      await new Promise((resolve, reject) => {
        server.close((err) => {
          if (err) reject(err);
          else resolve();
        });
      });
    }
  });
});

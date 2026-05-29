'use strict';

describe('config foundation', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    const testEnv = {
      ...originalEnv,
      NODE_ENV: 'test',
      PORT: '3000',
      DB_HOST: 'localhost',
      DB_NAME: 'numlab',
      DB_USER: 'numlab_user',
      DB_PASSWORD: 'changeme',
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
    expect(env.DB_PORT).toBe(5432);
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
});

describe('Express app foundation', () => {
  test('GET /health returns ok', async () => {
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
      expect(body).toEqual({ status: 'ok' });
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

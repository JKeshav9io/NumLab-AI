'use strict';

describe('config foundation', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = {
      ...originalEnv,
      NODE_ENV: 'test',
      PORT: '3000',
      DB_HOST: 'localhost',
      DB_NAME: 'numlab',
      DB_USER: 'numlab_user',
      DB_PASSWORD: 'changeme',
      JWT_SECRET: 'test-secret',
      AI_API_KEY: 'test-key',
    };
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
  });

  test('loads pino logger', () => {
    const logger = require('../config/logger');

    expect(typeof logger.info).toBe('function');
    expect(typeof logger.error).toBe('function');
  });
});

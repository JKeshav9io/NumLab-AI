'use strict';

const pino = require('pino');

const isTest = process.env.NODE_ENV === 'test';
const isProduction = process.env.NODE_ENV === 'production';

module.exports = pino({
  level: isTest ? 'silent' : isProduction ? 'info' : 'debug',
  transport: !isTest && !isProduction
    ? {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'SYS:standard',
      },
    }
    : undefined,
});

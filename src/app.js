'use strict';

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const errorHandler = require('./common/middleware/errorHandler');
const requestLogger = require('./common/middleware/requestLogger');

function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));
  app.use((req, _res, next) => {
    req.id = uuidv4();
    next();
  });
  app.use(requestLogger);

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  // Route modules will be mounted here as each feature slice is implemented.

  app.use(errorHandler);

  return app;
}

module.exports = createApp;

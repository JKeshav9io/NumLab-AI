'use strict';

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const errorHandler = require('./common/middleware/errorHandler');
const requestLogger = require('./common/middleware/requestLogger');
const { explainLimiter, solveLimiter } = require('./common/middleware/rateLimiter');
const explanationsRoutes = require('./modules/explanations/explanations.routes');
const solversRoutes = require('./modules/solvers/solvers.routes');

function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use((req, _res, next) => {
    req.id = uuidv4();
    next();
  });
  app.use(express.json({ limit: '1mb' }));
  app.use(requestLogger);

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/api/v1/solve', solveLimiter, solversRoutes);
  app.use('/api/v1/explain', explainLimiter, explanationsRoutes);

  app.use(errorHandler);

  return app;
}

module.exports = createApp;

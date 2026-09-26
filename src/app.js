'use strict';

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const compression = require('compression');
const errorHandler = require('./common/middleware/errorHandler');
const requestLogger = require('./common/middleware/requestLogger');
const { explainLimiter, solveLimiter, reportLimiter } = require('./common/middleware/rateLimiter');
const authenticate = require('./common/middleware/authenticate');
const explanationsRoutes = require('./modules/explanations/explanations.routes');
const solversRoutes = require('./modules/solvers/solvers.routes');
const authRoutes = require('./modules/auth/auth.routes');
const usersRoutes = require('./modules/users/users.routes');
const reportsRoutes = require('./modules/reports/reports.routes');

function createApp(options = {}) {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(compression());
  app.use((req, _res, next) => {
    req.id = uuidv4();
    next();
  });
  app.use(express.json({ limit: '1mb' }));
  app.use(requestLogger);

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  // Public numerical solver & explanation routes (rate-limited, no auth required)
  app.use('/api/v1/solve', solveLimiter, solversRoutes);
  app.use('/api/v1/explain', explainLimiter, explanationsRoutes);

  // Authentication, user, & report routes
  app.use('/api/v1/auth', authRoutes);
  app.use('/api/v1/users', usersRoutes);

  // Protected PDF report routes: authenticate runs BEFORE reportLimiter
  // so keyGenerator can key by authenticated req.user.id
  const activeReportLimiter = options.reportLimiter || reportLimiter;
  app.use('/api/v1/reports', authenticate, activeReportLimiter, reportsRoutes);

  app.use(errorHandler);

  return app;
}

module.exports = createApp;


'use strict';

const env = require('./config/env');
const logger = require('./config/logger');
const createApp = require('./app');
const { prisma, gracefulShutdown } = require('./db');

async function startServer() {
  try {
    // Fail fast if database connection cannot be established
    logger.info('Connecting to PostgreSQL database via Prisma...');
    await prisma.$connect();
    logger.info('Database connection established successfully');

    const app = createApp();

    const server = app.listen(env.PORT, () => {
      logger.info(`NumLab API running on port ${env.PORT} [${env.NODE_ENV}]`);
    });

    let isShuttingDown = false;
    const shutdown = async (signal) => {
      if (isShuttingDown) return;
      isShuttingDown = true;

      logger.info(`Received ${signal}. Starting graceful shutdown...`);

      server.close(async (err) => {
        if (err) {
          logger.error({ err }, 'Error closing HTTP server');
        } else {
          logger.info('HTTP server closed');
        }

        await gracefulShutdown();
        process.exit(0);
      });

      // Force exit if shutdown takes too long
      setTimeout(() => {
        logger.error('Graceful shutdown timed out. Forcing process exit.');
        process.exit(1);
      }, 10000).unref();
    };

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));

    return { server, app };
  } catch (error) {
    logger.error({ err: error }, 'Fatal error during server startup');
    console.error('FATAL: Failed to connect to database on startup. Check DATABASE_URL:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  startServer();
}

module.exports = { startServer };

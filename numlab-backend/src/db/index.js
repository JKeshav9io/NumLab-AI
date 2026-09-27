'use strict';

const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const env = require('../config/env');
const logger = require('../config/logger');

// Neon connection pooling considerations:
// Neon's pooled endpoint uses PgBouncer in transaction pooling mode.
// We configure connection pool bounds to avoid exhausting Neon session limits.
const adapter = new PrismaPg({
  connectionString: env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

const prisma = new PrismaClient({
  adapter,
  log: env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
});

/**
 * Performs a lightweight health check query against PostgreSQL.
 * @returns {Promise<{ status: string, database?: string, error?: string }>}
 */
async function healthCheck() {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return { status: 'healthy', database: 'connected' };
  } catch (error) {
    logger.error({ err: error }, 'Database health check query failed');
    return { status: 'unhealthy', error: error.message };
  }
}

/**
 * Closes the Prisma database connection pool cleanly.
 * @returns {Promise<void>}
 */
async function gracefulShutdown() {
  try {
    logger.info('Disconnecting Prisma database client...');
    await prisma.$disconnect();
    logger.info('Prisma database client disconnected cleanly');
  } catch (error) {
    logger.error({ err: error }, 'Error while disconnecting database client');
  }
}

module.exports = {
  prisma,
  healthCheck,
  gracefulShutdown,
  get cleanupExpiredRecords() {
    return require('./cleanup').cleanupExpiredRecords;
  },
};

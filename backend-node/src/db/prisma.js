// Zhouyi Backend - Prisma Client (BE-003)

const { PrismaClient } = require('@prisma/client');
const { getEnv } = require('../config/env');
const { createLogger } = require('../shared/logger');

const logger = createLogger('db');

let prisma = null;

function getPrisma() {
  if (prisma) return prisma;
  const env = getEnv();
  prisma = new PrismaClient({
    log: env.NODE_ENV === 'development' ? ['query', 'warn', 'error'] : ['warn', 'error'],
  });
  logger.info('Prisma client initialized');
  return prisma;
}

async function disconnectPrisma() {
  if (prisma) {
    await prisma.$disconnect();
    prisma = null;
    logger.info('Prisma client disconnected');
  }
}

module.exports = { getPrisma, disconnectPrisma };

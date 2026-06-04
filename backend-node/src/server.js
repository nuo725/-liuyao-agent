// Zhouyi Backend - Server Entry Point (BE-001)

const { createApp } = require('./app');
const { getEnv } = require('./config/env');
const { createLogger } = require('./shared/logger');
const { disconnectPrisma } = require('./db/prisma');

const logger = createLogger('server');

async function main() {
  const env = getEnv();
  const app = createApp();

  const server = app.listen(env.PORT, '0.0.0.0', () => {
    logger.info(`Zhouyi backend listening on http://0.0.0.0:${env.PORT}/api/v1`);
    logger.info(`Environment: ${env.NODE_ENV}`);
  });

  // Graceful shutdown
  const shutdown = async (signal) => {
    logger.info(`${signal} received, shutting down...`);
    server.close(async () => {
      await disconnectPrisma();
      logger.info('Server stopped');
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((err) => {
  logger.fatal({ err }, 'Failed to start server');
  process.exit(1);
});

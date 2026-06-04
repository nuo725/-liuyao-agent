// PostgreSQL Outbox worker.

const { getPrisma, disconnectPrisma } = require('../db/prisma');
const { createLogger } = require('../shared/logger');

const logger = createLogger('outbox-worker');
const POLL_INTERVAL_MS = Number(process.env.OUTBOX_POLL_INTERVAL_MS || 3000);
const LOCK_TIMEOUT_MS = Number(process.env.OUTBOX_LOCK_TIMEOUT_MS || 60_000);

let stopped = false;

async function runOnce() {
  const prisma = getPrisma();
  const now = new Date();
  const lockExpiredBefore = new Date(now.getTime() - LOCK_TIMEOUT_MS);

  const job = await prisma.outboxJob.findFirst({
    where: {
      availableAt: { lte: now },
      OR: [
        { status: 'pending' },
        { status: 'processing', lockedAt: { lt: lockExpiredBefore } },
      ],
    },
    orderBy: { createdAt: 'asc' },
  });

  if (!job) {
    return false;
  }

  const locked = await prisma.outboxJob.updateMany({
    where: {
      id: job.id,
      OR: [
        { status: 'pending' },
        { status: 'processing', lockedAt: { lt: lockExpiredBefore } },
      ],
    },
    data: {
      status: 'processing',
      lockedAt: now,
      attempts: { increment: 1 },
    },
  });

  if (locked.count !== 1) {
    return false;
  }

  try {
    await processJob(job.type, job.payload);
    await prisma.outboxJob.update({
      where: { id: job.id },
      data: {
        status: 'completed',
        lockedAt: null,
        lastError: null,
      },
    });
    logger.info({ jobId: job.id, type: job.type }, 'Outbox job completed');
  } catch (err) {
    const attempts = job.attempts + 1;
    const failed = attempts >= job.maxAttempts;
    await prisma.outboxJob.update({
      where: { id: job.id },
      data: {
        status: failed ? 'failed' : 'pending',
        lockedAt: null,
        availableAt: new Date(Date.now() + Math.min(60_000, attempts * 5000)),
        lastError: err.message || String(err),
      },
    });
    logger.error({ err, jobId: job.id, type: job.type, failed }, 'Outbox job failed');
  }

  return true;
}

async function processJob(type, payload) {
  if (type === 'notification.push') {
    logger.info({ payload }, 'Push notification adapter not configured; job acknowledged');
    return;
  }
  if (type === 'moderation.review') {
    logger.info({ payload }, 'Moderation review job acknowledged');
    return;
  }
  logger.warn({ type, payload }, 'Unknown outbox job type; acknowledged');
}

async function loop() {
  logger.info('Outbox worker started');
  while (!stopped) {
    const processed = await runOnce();
    if (!processed) {
      await sleep(POLL_INTERVAL_MS);
    }
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

if (require.main === module) {
  process.on('SIGINT', async () => {
    stopped = true;
    await disconnectPrisma();
    process.exit(0);
  });
  process.on('SIGTERM', async () => {
    stopped = true;
    await disconnectPrisma();
    process.exit(0);
  });
  loop().catch(async (err) => {
    logger.error({ err }, 'Outbox worker crashed');
    await disconnectPrisma();
    process.exit(1);
  });
}

module.exports = {
  runOnce,
  processJob,
};

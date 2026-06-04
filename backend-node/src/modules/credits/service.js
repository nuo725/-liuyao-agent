// Credits Module - Business Logic Service

const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const { createLogger } = require('../../shared/logger');

const logger = createLogger('credits-service');

// Default daily quotas
const DAILY_QUOTAS = {
  normal: { cast: 1, followup: 1 },
  vip: { cast: 2, followup: 4 },
};

/**
 * Get credit account with auto daily reset.
 */
async function getAccount(userId) {
  const prisma = getPrisma();
  let account = await prisma.creditAccount.findUnique({ where: { userId } });

  if (!account) {
    account = await prisma.creditAccount.create({
      data: { userId },
    });
  }

  // Auto daily reset
  const today = new Date().toISOString().split('T')[0];
  if (account.lastResetDate !== today) {
    const quota = account.isVip ? DAILY_QUOTAS.vip : DAILY_QUOTAS.normal;
    account = await prisma.creditAccount.update({
      where: { userId },
      data: {
        castBalance: quota.cast,
        followupBalance: quota.followup,
        lastResetDate: today,
      },
    });
    logger.info({ userId }, 'Daily credit reset');
  }

  return formatAccount(account);
}

/**
 * Consume credits with idempotency.
 */
async function consume(userId, type, amount = 1, idempotencyKey) {
  const prisma = getPrisma();

  // Check idempotency
  if (idempotencyKey) {
    const existing = await prisma.creditLedger.findUnique({
      where: { idempotencyKey },
    });
    if (existing) {
      logger.debug({ idempotencyKey }, 'Idempotent consume replay');
      const account = await getAccount(userId);
      return account;
    }
  }

  // Get current account (triggers auto-reset if needed)
  const account = await getAccount(userId);

  // Check balance
  const balanceField = type === 'cast' ? 'castBalance' : 'followupBalance';
  if (account[balanceField] < amount) {
    throw ApiError.conflict(`Insufficient ${type} balance: ${account[balanceField]} < ${amount}`);
  }

  // Consume in transaction
  const [updatedAccount] = await prisma.$transaction([
    prisma.creditAccount.update({
      where: { userId },
      data: { [balanceField]: { decrement: amount } },
    }),
    prisma.creditLedger.create({
      data: {
        userId,
        type,
        amount: -amount,
        reason: `Consumed ${amount} ${type}`,
        idempotencyKey: idempotencyKey || null,
      },
    }),
  ]);

  logger.info({ userId, type, amount }, 'Credit consumed');

  return formatAccount(updatedAccount);
}

/**
 * Manual daily reset (rarely used).
 */
async function resetDaily(userId) {
  return await getAccount(userId); // getAccount handles auto-reset
}

function formatAccount(account) {
  return {
    userId: account.userId,
    castBalance: account.castBalance,
    followupBalance: account.followupBalance,
    isVip: account.isVip,
    vipExpiresAt: account.vipExpiresAt,
    lastResetDate: account.lastResetDate,
    lastCheckinDate: account.lastCheckinDate,
  };
}

module.exports = { getAccount, consume, resetDaily };

// Billing Module - Business Logic Service

const { createHmac, randomUUID } = require('crypto');
const { getPrisma } = require('../../db/prisma');
const { getEnv } = require('../../config/env');
const { ApiError } = require('../../shared/api-error');
const { createLogger } = require('../../shared/logger');

const logger = createLogger('billing-service');

async function listPlans() {
  const prisma = getPrisma();
  const plans = await prisma.billingPlan.findMany({
    where: { active: true },
    orderBy: { priceCents: 'asc' },
  });
  return { items: plans.map(formatPlan) };
}

async function createOrder(userId, planId, idempotencyKey) {
  const prisma = getPrisma();

  if (idempotencyKey) {
    const existing = await prisma.billingOrder.findUnique({ where: { idempotencyKey } });
    if (existing && existing.userId === userId) {
      return formatOrder(existing);
    }
  }

  const plan = await prisma.billingPlan.findFirst({
    where: { id: planId, active: true },
  });
  if (!plan) {
    throw ApiError.notFound('Billing plan not found');
  }

  const order = await prisma.billingOrder.create({
    data: {
      orderId: `ord_${Date.now()}_${randomUUID().slice(0, 8)}`,
      userId,
      planId: plan.id,
      status: 'created',
      amount: plan.priceCents,
      idempotencyKey: idempotencyKey || null,
    },
  });

  logger.info({ userId, orderId: order.orderId, planId }, 'Billing order created');
  return formatOrder(order);
}

async function confirmPayment(userId, orderId, providerOrderId, signature) {
  const prisma = getPrisma();
  const env = getEnv();

  const order = await prisma.billingOrder.findUnique({
    where: { orderId },
    include: { plan: true },
  });

  if (!order || order.userId !== userId) {
    throw ApiError.notFound('Order not found');
  }

  if (order.status === 'paid') {
    return formatOrder(order);
  }

  if (env.NODE_ENV === 'production' && !isValidSignature(orderId, providerOrderId || '', signature, env.PAYMENT_CALLBACK_SECRET)) {
    throw ApiError.forbidden('Invalid payment signature');
  }

  const now = new Date();
  const account = await prisma.creditAccount.upsert({
    where: { userId },
    update: {},
    create: { userId },
  });
  const vipStart = account.vipExpiresAt && account.vipExpiresAt > now ? account.vipExpiresAt : now;
  const vipExpiresAt = new Date(vipStart.getTime() + order.plan.days * 24 * 60 * 60 * 1000);

  const [updatedOrder] = await prisma.$transaction([
    prisma.billingOrder.update({
      where: { orderId },
      data: {
        status: 'paid',
        providerOrderId: providerOrderId || order.providerOrderId,
      },
    }),
    prisma.creditAccount.update({
      where: { userId },
      data: {
        isVip: true,
        vipExpiresAt,
        castBalance: { increment: 1 },
        followupBalance: { increment: 3 },
      },
    }),
    prisma.creditLedger.create({
      data: {
        userId,
        type: 'purchase',
        amount: order.plan.days,
        reason: `VIP plan purchased: ${order.plan.name}`,
      },
    }),
  ]);

  logger.info({ userId, orderId }, 'Payment confirmed and VIP activated');
  return formatOrder(updatedOrder);
}

async function getOrder(userId, orderId) {
  const prisma = getPrisma();
  const order = await prisma.billingOrder.findUnique({ where: { orderId } });
  if (!order || order.userId !== userId) {
    throw ApiError.notFound('Order not found');
  }
  return formatOrder(order);
}

function isValidSignature(orderId, providerOrderId, signature, secret) {
  if (!signature) return false;
  const expected = createHmac('sha256', secret)
    .update(`${orderId}:${providerOrderId}`)
    .digest('hex');
  return expected === signature;
}

function formatPlan(plan) {
  return {
    id: plan.id,
    name: plan.name,
    days: plan.days,
    priceCents: plan.priceCents,
    currency: plan.currency,
  };
}

function formatOrder(order) {
  return {
    orderId: order.orderId,
    planId: order.planId,
    status: order.status,
    amount: order.amount,
    providerOrderId: order.providerOrderId,
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
  };
}

module.exports = {
  listPlans,
  createOrder,
  confirmPayment,
  getOrder,
};

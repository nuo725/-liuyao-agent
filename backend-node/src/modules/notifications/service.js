// Notifications Module - Business Logic Service

const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const { createLogger } = require('../../shared/logger');

const logger = createLogger('notifications-service');

async function createNotification(userId, data) {
  const prisma = getPrisma();
  const [notification] = await prisma.$transaction([
    prisma.notification.create({
      data: {
        userId,
        type: data.type,
        title: data.title,
        body: data.body || '',
        data: data.data || {},
      },
    }),
    prisma.outboxJob.create({
      data: {
        type: 'notification.push',
        payload: {
          userId,
          notificationType: data.type,
          title: data.title,
          body: data.body || '',
          data: data.data || {},
        },
      },
    }),
  ]);
  logger.info({ userId, notificationId: notification.id, type: notification.type }, 'Notification created');
  return formatNotification(notification);
}

async function listNotifications(userId, type = 'all', page = 1, pageSize = 20) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;
  const where = {
    userId,
    dismissedAt: null,
    ...(type !== 'all' && { type }),
  };

  const [items, total, unreadCount] = await Promise.all([
    prisma.notification.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: pageSize,
    }),
    prisma.notification.count({ where }),
    getUnreadCount(userId),
  ]);

  return {
    items: items.map(formatNotification),
    hasMore: skip + items.length < total,
    nextPage: skip + items.length < total ? page + 1 : null,
    unreadCount: unreadCount.count,
  };
}

async function getUnreadCount(userId) {
  const prisma = getPrisma();
  const count = await prisma.notification.count({
    where: { userId, readAt: null, dismissedAt: null },
  });
  return { count };
}

async function markRead(userId, notificationId) {
  const prisma = getPrisma();
  const notification = await findOwnedNotification(prisma, userId, notificationId);
  if (!notification.readAt) {
    await prisma.notification.update({
      where: { id: notificationId },
      data: { readAt: new Date() },
    });
  }
  return { read: true };
}

async function markAllRead(userId) {
  const prisma = getPrisma();
  const result = await prisma.notification.updateMany({
    where: { userId, readAt: null, dismissedAt: null },
    data: { readAt: new Date() },
  });
  return { updated: result.count };
}

async function dismiss(userId, notificationId) {
  const prisma = getPrisma();
  await findOwnedNotification(prisma, userId, notificationId);
  await prisma.notification.update({
    where: { id: notificationId },
    data: { dismissedAt: new Date() },
  });
  return { dismissed: true };
}

async function registerToken(userId, token, platform) {
  const prisma = getPrisma();
  const pushToken = await prisma.pushToken.upsert({
    where: { token },
    update: { userId, platform },
    create: { userId, token, platform },
  });
  return {
    id: pushToken.id,
    token: pushToken.token,
    platform: pushToken.platform,
    createdAt: pushToken.createdAt,
  };
}

async function unregisterToken(userId, token) {
  const prisma = getPrisma();
  const where = token ? { userId, token } : { userId };
  const result = await prisma.pushToken.deleteMany({ where });
  return { deleted: result.count };
}

async function syncState(userId, readIds = [], dismissedIds = []) {
  const prisma = getPrisma();
  const now = new Date();
  const [readResult, dismissedResult] = await prisma.$transaction([
    prisma.notification.updateMany({
      where: { userId, id: { in: readIds }, readAt: null },
      data: { readAt: now },
    }),
    prisma.notification.updateMany({
      where: { userId, id: { in: dismissedIds } },
      data: { dismissedAt: now },
    }),
  ]);
  return {
    read: readResult.count,
    dismissed: dismissedResult.count,
  };
}

async function findOwnedNotification(prisma, userId, notificationId) {
  const notification = await prisma.notification.findFirst({
    where: { id: notificationId, userId },
  });
  if (!notification) {
    throw ApiError.notFound('Notification not found');
  }
  return notification;
}

function formatNotification(notification) {
  return {
    id: notification.id,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    data: notification.data || {},
    createdAt: notification.createdAt,
    read: !!notification.readAt,
  };
}

module.exports = {
  createNotification,
  listNotifications,
  getUnreadCount,
  markRead,
  markAllRead,
  dismiss,
  registerToken,
  unregisterToken,
  syncState,
};

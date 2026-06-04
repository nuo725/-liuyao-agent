// Activities Module - Business Logic Service

const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const notificationService = require('../notifications/service');

async function listActivities(page = 1, pageSize = 20, userId = null) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  const [activities, total] = await Promise.all([
    prisma.activity.findMany({
      orderBy: [{ status: 'asc' }, { startAt: 'asc' }],
      skip,
      take: pageSize,
    }),
    prisma.activity.count(),
  ]);

  const joinMap = await getJoinMap(prisma, userId, activities.map((activity) => activity.id));

  return {
    items: activities.map((activity) => formatActivity(activity, joinMap.get(activity.id))),
    hasMore: skip + activities.length < total,
    nextPage: skip + activities.length < total ? page + 1 : null,
  };
}

async function getActivityDetail(activityId, userId = null) {
  const prisma = getPrisma();
  const activity = await prisma.activity.findUnique({ where: { id: activityId } });
  if (!activity) {
    throw ApiError.notFound('Activity not found');
  }
  const join = userId
    ? await prisma.activityJoin.findUnique({ where: { activityId_userId: { activityId, userId } } })
    : null;
  return formatActivity(activity, join?.status);
}

async function joinActivity(activityId, userId) {
  const prisma = getPrisma();
  const activity = await prisma.activity.findUnique({ where: { id: activityId } });
  if (!activity) {
    throw ApiError.notFound('Activity not found');
  }
  if (activity.status === 'ended') {
    throw ApiError.conflict('Activity has ended');
  }

  const existing = await prisma.activityJoin.findUnique({
    where: { activityId_userId: { activityId, userId } },
  });
  if (existing) {
    return { status: existing.status };
  }

  const hasCapacity = !activity.capacity || activity.participantCount < activity.capacity;
  const status = hasCapacity ? 'approved' : 'waitlist';

  await prisma.$transaction([
    prisma.activityJoin.create({
      data: { activityId, userId, status },
    }),
    ...(status === 'approved'
      ? [
          prisma.activity.update({
            where: { id: activityId },
            data: { participantCount: { increment: 1 } },
          }),
        ]
      : []),
  ]);

  await notificationService.createNotification(userId, {
    type: 'activity',
    title: status === 'approved' ? '活动报名成功' : '你已进入活动候补',
    body: activity.title,
    data: { targetId: activityId, targetType: 'activity', status },
  }).catch(() => {});

  return { status };
}

async function getJoinStatus(activityId, userId) {
  const prisma = getPrisma();
  const join = await prisma.activityJoin.findUnique({
    where: { activityId_userId: { activityId, userId } },
  });
  return { status: join?.status || 'none' };
}

async function createActivity(data, operatorId) {
  const prisma = getPrisma();
  const activity = await prisma.activity.create({
    data: normalizeActivityData(data),
  });
  await createActivityNotification(activity, operatorId, 'created');
  return formatActivity(activity);
}

async function updateActivity(activityId, data, operatorId) {
  const prisma = getPrisma();
  const existing = await prisma.activity.findUnique({ where: { id: activityId } });
  if (!existing) {
    throw ApiError.notFound('Activity not found');
  }

  const activity = await prisma.activity.update({
    where: { id: activityId },
    data: normalizeActivityData(data),
  });

  if (data.status && data.status !== existing.status) {
    await notifyActivityParticipants(prisma, activity, data.status).catch(() => {});
  }
  await createActivityNotification(activity, operatorId, 'updated');
  return formatActivity(activity);
}

async function getJoinMap(prisma, userId, activityIds) {
  if (!userId || activityIds.length === 0) {
    return new Map();
  }
  const joins = await prisma.activityJoin.findMany({
    where: { userId, activityId: { in: activityIds } },
  });
  return new Map(joins.map((join) => [join.activityId, join.status]));
}

function formatActivity(activity, joinStatus = null) {
  return {
    id: activity.id,
    title: activity.title,
    description: activity.description,
    imageUrl: activity.imageUrl,
    status: activity.status,
    startAt: activity.startAt,
    endAt: activity.endAt,
    capacity: activity.capacity,
    participantCount: activity.participantCount,
    joinStatus: joinStatus || 'none',
    createdAt: activity.createdAt,
    updatedAt: activity.updatedAt,
  };
}

function normalizeActivityData(data) {
  return {
    ...(data.title !== undefined && { title: data.title }),
    ...(data.description !== undefined && { description: data.description }),
    ...(data.imageUrl !== undefined && { imageUrl: data.imageUrl || null }),
    ...(data.status !== undefined && { status: data.status }),
    ...(data.startAt !== undefined && { startAt: data.startAt ? new Date(data.startAt) : null }),
    ...(data.endAt !== undefined && { endAt: data.endAt ? new Date(data.endAt) : null }),
    ...(data.capacity !== undefined && { capacity: data.capacity || null }),
  };
}

async function notifyActivityParticipants(prisma, activity, status) {
  const joins = await prisma.activityJoin.findMany({
    where: { activityId: activity.id, status: { in: ['approved', 'waitlist'] } },
    select: { userId: true },
  });

  await Promise.all(joins.map((join) => notificationService.createNotification(join.userId, {
    type: 'activity',
    title: '活动状态更新',
    body: `${activity.title} 已更新为 ${status}`,
    data: { targetId: activity.id, targetType: 'activity', status },
  })));
}

async function createActivityNotification(activity, operatorId, action) {
  if (!operatorId) return;
  await notificationService.createNotification(operatorId, {
    type: 'system',
    title: action === 'created' ? '活动已创建' : '活动已更新',
    body: activity.title,
    data: { targetId: activity.id, targetType: 'activity', action },
  }).catch(() => {});
}

module.exports = {
  listActivities,
  getActivityDetail,
  joinActivity,
  getJoinStatus,
  createActivity,
  updateActivity,
};

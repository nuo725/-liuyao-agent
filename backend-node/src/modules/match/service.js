// Match Module - Business Logic Service

const { createHash, randomUUID } = require('crypto');
const { getPrisma } = require('../../db/prisma');

async function unlock(userId, deviceId = null) {
  const prisma = getPrisma();
  const dateKey = todayKey();
  const resolvedDeviceId = deviceId || `user:${userId}`;
  const signature = buildSignature(userId, resolvedDeviceId, dateKey);

  const existing = await prisma.sameFrequencyUnlock.findUnique({
    where: { userId_dateKey: { userId, dateKey } },
  });

  const unlockRecord = existing || await prisma.sameFrequencyUnlock.create({
    data: {
      userId,
      deviceId: resolvedDeviceId,
      dateKey,
      signature,
    },
  });

  return {
    unlocked: true,
    unlockToken: unlockRecord.signature,
    signature: unlockRecord.signature,
    unlockedAt: unlockRecord.unlockedAt,
  };
}

async function getRadarStatus(userId) {
  const prisma = getPrisma();
  const dateKey = todayKey();
  const unlockRecord = await prisma.sameFrequencyUnlock.findUnique({
    where: { userId_dateKey: { userId, dateKey } },
  });

  return {
    unlocked: !!unlockRecord,
    signature: unlockRecord?.signature || null,
    unlockedAt: unlockRecord?.unlockedAt || null,
  };
}

async function getSameFrequency(userId, tab = 'users', page = 1, pageSize = 20) {
  const prisma = getPrisma();
  const status = await getRadarStatus(userId);
  if (!status.unlocked) {
    return {
      tab,
      signature: null,
      items: [],
      hasMore: false,
      nextPage: null,
      locked: true,
    };
  }

  return tab === 'history'
    ? getHistory(prisma, status.signature, page, pageSize)
    : getUsers(prisma, userId, status.signature, page, pageSize);
}

async function getUsers(prisma, userId, signature, page, pageSize) {
  const skip = (page - 1) * pageSize;
  const [users, total] = await Promise.all([
    prisma.user.findMany({
      where: { id: { not: userId }, status: 'active' },
      orderBy: { createdAt: 'desc' },
      skip,
      take: pageSize,
      select: { id: true, username: true, bio: true, avatarUrl: true, shortId: true },
    }),
    prisma.user.count({ where: { id: { not: userId }, status: 'active' } }),
  ]);

  return {
    tab: 'users',
    signature,
    items: users.map((user) => ({
      id: user.id,
      username: user.username,
      bio: user.bio,
      avatarUrl: user.avatarUrl,
      handle: user.shortId,
      matchReason: buildReason(signature, user.id),
    })),
    hasMore: skip + users.length < total,
    nextPage: skip + users.length < total ? page + 1 : null,
  };
}

async function getHistory(prisma, signature, page, pageSize) {
  const skip = (page - 1) * pageSize;
  const [posts, total] = await Promise.all([
    prisma.communityPost.findMany({
      where: { status: 'published' },
      orderBy: { createdAt: 'desc' },
      skip,
      take: pageSize,
      include: {
        author: { select: { id: true, username: true, avatarUrl: true } },
        card: { select: { communitySafeContent: true } },
      },
    }),
    prisma.communityPost.count({ where: { status: 'published' } }),
  ]);

  return {
    tab: 'history',
    signature,
    items: posts.map((post) => ({
      id: post.id,
      shareText: post.shareText,
      coverImageUrl: post.coverImageUrl,
      authorUsername: post.author?.username,
      authorAvatarUrl: post.author?.avatarUrl,
      cardSummary: post.card?.communitySafeContent?.summary || '',
      matchReason: buildReason(signature, post.id),
      createdAt: post.createdAt,
    })),
    hasMore: skip + posts.length < total,
    nextPage: skip + posts.length < total ? page + 1 : null,
  };
}

function todayKey() {
  return new Date().toISOString().split('T')[0];
}

function buildSignature(userId, deviceId, dateKey) {
  const hash = createHash('sha256').update(`${userId}:${deviceId}:${dateKey}`).digest('hex');
  return `freq_${hash.slice(0, 16)}`;
}

function buildReason(signature, seed = randomUUID()) {
  const bucket = parseInt(createHash('sha1').update(`${signature}:${seed}`).digest('hex').slice(0, 2), 16) % 3;
  return [
    '都在寻找让当下变清晰的一点线索',
    '近期都更关注关系与自我边界',
    '都在变化里练习慢一点做决定',
  ][bucket];
}

module.exports = {
  unlock,
  getRadarStatus,
  getSameFrequency,
};

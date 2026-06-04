// Profile Module - Business Logic Service

const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const { createLogger } = require('../../shared/logger');

const logger = createLogger('profile-service');

/**
 * Get current user's profile with settings.
 */
async function getMyProfile(userId) {
  const prisma = getPrisma();
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { profileSettings: true },
  });

  if (!user || user.status === 'deleted') {
    throw ApiError.notFound('User not found');
  }

  return {
    id: user.id,
    username: user.username,
    bio: user.bio,
    avatarUrl: user.avatarUrl,
    coverUrl: user.coverUrl,
    shortId: user.shortId,
    city: user.city,
    gender: user.gender,
    birthday: user.birthday,
    createdAt: user.createdAt,
    settings: user.profileSettings
      ? {
          pushEnabled: user.profileSettings.pushEnabled,
          vibrationEnabled: user.profileSettings.vibrationEnabled,
          ambientSoundEnabled: user.profileSettings.ambientSoundEnabled,
          publicProfile: user.profileSettings.publicProfile,
        }
      : null,
  };
}

/**
 * Update current user's profile (partial update).
 */
async function updateMyProfile(userId, data) {
  const prisma = getPrisma();

  // Check username uniqueness if changing
  if (data.username) {
    const existing = await prisma.user.findFirst({
      where: {
        username: data.username,
        id: { not: userId },
      },
    });
    if (existing) {
      throw ApiError.conflict('Username already taken');
    }
  }

  const user = await prisma.user.update({
    where: { id: userId },
    data: {
      ...(data.username !== undefined && { username: data.username }),
      ...(data.bio !== undefined && { bio: data.bio }),
      ...(data.city !== undefined && { city: data.city }),
      ...(data.gender !== undefined && { gender: data.gender }),
      ...(data.birthday !== undefined && { birthday: data.birthday ? new Date(data.birthday) : null }),
    },
  });

  logger.info({ userId }, 'Profile updated');

  return {
    id: user.id,
    username: user.username,
    bio: user.bio,
    avatarUrl: user.avatarUrl,
    coverUrl: user.coverUrl,
    shortId: user.shortId,
    city: user.city,
    gender: user.gender,
    birthday: user.birthday,
    createdAt: user.createdAt,
  };
}

/**
 * Get user settings.
 */
async function getMySettings(userId) {
  const prisma = getPrisma();
  const settings = await prisma.profileSettings.findUnique({
    where: { userId },
  });

  if (!settings) {
    // Create default settings if not exists
    return await prisma.profileSettings.create({
      data: { userId },
    });
  }

  return settings;
}

/**
 * Update user settings.
 */
async function updateMySettings(userId, data) {
  const prisma = getPrisma();

  const settings = await prisma.profileSettings.upsert({
    where: { userId },
    update: data,
    create: { userId, ...data },
  });

  logger.info({ userId }, 'Settings updated');
  return settings;
}

/**
 * Get checkin calendar for a month.
 */
async function getCheckinCalendar(userId, month) {
  const prisma = getPrisma();
  const targetMonth = month || new Date().toISOString().slice(0, 7);
  const [year, mon] = targetMonth.split('-').map(Number);

  // Get all checkin records for the month
  const startDate = `${targetMonth}-01`;
  const endDate = `${year}-${String(mon + 1).padStart(2, '0')}-01`;
  const safeEndDate = mon === 12 ? `${year + 1}-01-01` : endDate;

  const records = await prisma.checkinRecord.findMany({
    where: {
      userId,
      dateKey: { gte: startDate, lt: safeEndDate },
    },
    orderBy: { dateKey: 'asc' },
  });

  const checkedDays = records.map((r) => parseInt(r.dateKey.split('-')[2], 10));

  // Calculate streak
  const today = new Date().toISOString().split('T')[0];
  let streak = 0;
  let currentDate = new Date();

  while (true) {
    const dateKey = currentDate.toISOString().split('T')[0];
    const hasRecord = records.some((r) => r.dateKey === dateKey);
    if (!hasRecord) break;
    streak++;
    currentDate.setDate(currentDate.getDate() - 1);
  }

  const hasCheckedInToday = records.some((r) => r.dateKey === today);

  return {
    month: targetMonth,
    checkedDays,
    streak,
    hasCheckedInToday,
  };
}

/**
 * Perform daily check-in.
 */
async function checkin(userId) {
  const prisma = getPrisma();
  const today = new Date().toISOString().split('T')[0];

  // Check if already checked in
  const existing = await prisma.checkinRecord.findUnique({
    where: { userId_dateKey: { userId, dateKey: today } },
  });

  if (existing) {
    const calendar = await getCheckinCalendar(userId);
    return {
      streak: calendar.streak,
      reward: 0,
      alreadyCheckedIn: true,
    };
  }

  await prisma.$transaction([
    prisma.checkinRecord.create({
      data: { userId, dateKey: today },
    }),
    prisma.creditAccount.upsert({
      where: { userId },
      update: {
        lastCheckinDate: today,
        followupBalance: { increment: 1 },
      },
      create: {
        userId,
        lastCheckinDate: today,
        followupBalance: 2,
      },
    }),
    prisma.creditLedger.create({
      data: {
        userId,
        type: 'checkin',
        amount: 1,
        reason: 'Daily check-in reward',
        idempotencyKey: `checkin:${userId}:${today}`,
      },
    }),
  ]);

  logger.info({ userId }, 'Check-in completed');

  // Calculate streak
  const calendar = await getCheckinCalendar(userId);

  return {
    streak: calendar.streak,
    reward: 1,
    alreadyCheckedIn: false,
  };
}

/**
 * Get interaction records.
 */
async function getInteractions(userId, page = 1, pageSize = 20) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  // Get user's likes, comments, follows, posts
  const [likes, comments, follows, posts] = await Promise.all([
    prisma.postLike.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: pageSize,
      skip,
    }),
    prisma.comment.findMany({
      where: { userId, status: 'visible' },
      orderBy: { createdAt: 'desc' },
      take: pageSize,
      skip,
    }),
    prisma.userFollow.findMany({
      where: { followerId: userId },
      orderBy: { createdAt: 'desc' },
      take: pageSize,
      skip,
    }),
    prisma.communityPost.findMany({
      where: { authorId: userId, status: 'published' },
      orderBy: { createdAt: 'desc' },
      take: pageSize,
      skip,
    }),
  ]);

  // Combine and sort by date
  const items = [
    ...likes.map((l) => ({ type: 'like', postId: l.postId, createdAt: l.createdAt })),
    ...comments.map((c) => ({ type: 'comment', commentId: c.id, postId: c.postId, text: c.text, createdAt: c.createdAt })),
    ...follows.map((f) => ({ type: 'follow', followingId: f.followingId, createdAt: f.createdAt })),
    ...posts.map((p) => ({ type: 'publish', postId: p.id, shareText: p.shareText, createdAt: p.createdAt })),
  ].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  return {
    items: items.slice(0, pageSize),
    hasMore: items.length >= pageSize,
    nextPage: items.length >= pageSize ? page + 1 : null,
  };
}

/**
 * Get browse history.
 */
async function getBrowseHistory(userId, page = 1, pageSize = 20) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  const [views, total] = await Promise.all([
    prisma.postView.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip,
      take: pageSize,
    }),
    prisma.postView.count({ where: { userId } }),
  ]);

  const posts = views.length > 0
    ? await prisma.communityPost.findMany({
        where: { id: { in: views.map((view) => view.postId) } },
        include: {
          author: { select: { id: true, username: true, avatarUrl: true } },
        },
      })
    : [];
  const postMap = new Map(posts.map((post) => [post.id, post]));

  return {
    items: views
      .map((view) => {
        const post = postMap.get(view.postId);
        if (!post) return null;
        return {
          type: 'post',
          postId: post.id,
          shareText: post.shareText,
          coverImageUrl: post.coverImageUrl,
          authorId: post.authorId,
          authorUsername: post.author?.username,
          viewedAt: view.createdAt,
        };
      })
      .filter(Boolean),
    hasMore: skip + views.length < total,
    nextPage: skip + views.length < total ? page + 1 : null,
  };
}

async function updateAvatar(userId, mediaId) {
  return updateProfileMedia(userId, mediaId, 'avatar');
}

async function updateCover(userId, mediaId) {
  return updateProfileMedia(userId, mediaId, 'cover');
}

async function getShareCard(userId) {
  const profile = await getMyProfile(userId);
  return {
    title: profile.username || '宽窄 Orbit',
    summary: profile.bio || '在宽窄之间，记录一次真实的自我梳理。',
    link: `/profile/${profile.shortId}`,
    avatarUrl: profile.avatarUrl,
    coverUrl: profile.coverUrl,
  };
}

async function updateProfileMedia(userId, mediaId, purpose) {
  const prisma = getPrisma();
  const media = await prisma.mediaAsset.findFirst({
    where: { id: mediaId, ownerId: userId, purpose, status: 'active' },
  });
  if (!media) {
    throw ApiError.notFound(`Active ${purpose} media not found`);
  }

  const data = purpose === 'avatar' ? { avatarUrl: media.url } : { coverUrl: media.url };
  const user = await prisma.user.update({
    where: { id: userId },
    data,
  });
  logger.info({ userId, mediaId, purpose }, 'Profile media updated');
  return {
    id: user.id,
    username: user.username,
    avatarUrl: user.avatarUrl,
    coverUrl: user.coverUrl,
  };
}

/**
 * Request account deletion (with cooling-off period).
 */
async function requestDeleteAccount(userId, confirmText) {
  const prisma = getPrisma();

  if (confirmText !== '注销') {
    throw ApiError.badRequest('请输入"注销"确认');
  }

  // Mark user as deleted (soft delete with cooling-off)
  await prisma.user.update({
    where: { id: userId },
    data: { status: 'deleted' },
  });

  logger.info({ userId }, 'Account deletion requested');

  return {
    coolingOffDays: 7,
    message: '账号将在7天后永久删除，期间可联系客服撤销',
  };
}

module.exports = {
  getMyProfile,
  updateMyProfile,
  getMySettings,
  updateMySettings,
  getCheckinCalendar,
  checkin,
  getInteractions,
  getBrowseHistory,
  requestDeleteAccount,
  updateAvatar,
  updateCover,
  getShareCard,
};

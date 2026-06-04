// Community Module - Business Logic Service

const { randomUUID } = require('crypto');
const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const { createLogger } = require('../../shared/logger');
const moderation = require('./moderation');
const notificationService = require('../notifications/service');

const logger = createLogger('community-service');

/**
 * Get feed by tab (recommended or deep).
 */
async function getFeed(tab, page = 1, pageSize = 20, viewerId) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  // Deep tab: filter by longer text or specific tags
  const where = { status: 'published' };
  if (tab === 'deep') {
    where.OR = [
      { tabTags: { has: 'reflection' } },
      { tabTags: { has: 'emotion' } },
      { tabTags: { has: 'career' } },
      { tabTags: { has: 'relationship' } },
    ];
  }

  if (viewerId) {
    const [hiddenPosts, blockedUsers] = await Promise.all([
      prisma.postHide.findMany({ where: { userId: viewerId }, select: { postId: true } }),
      prisma.userBlock.findMany({ where: { blockerId: viewerId }, select: { blockedUserId: true } }),
    ]);
    const hiddenPostIds = hiddenPosts.map((item) => item.postId);
    const blockedUserIds = blockedUsers.map((item) => item.blockedUserId);
    if (hiddenPostIds.length > 0) {
      where.id = { notIn: hiddenPostIds };
    }
    if (blockedUserIds.length > 0) {
      where.authorId = { notIn: blockedUserIds };
    }
  }

  const [posts, total] = await Promise.all([
    prisma.communityPost.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: pageSize,
      include: {
        author: { select: { id: true, username: true, avatarUrl: true } },
        card: { select: { communitySafeContent: true, riskLevel: true } },
      },
    }),
    prisma.communityPost.count({ where }),
  ]);

  // Get viewer state if authenticated
  const items = await Promise.all(
    posts.map(async (post) => {
      let viewerState = { liked: false, favorited: false, followedAuthor: false };
      if (viewerId) {
        const [like, favorite, follow] = await Promise.all([
          prisma.postLike.findUnique({ where: { userId_postId: { userId: viewerId, postId: post.id } } }),
          prisma.postFavorite.findUnique({ where: { userId_postId: { userId: viewerId, postId: post.id } } }),
          prisma.userFollow.findUnique({ where: { followerId_followingId: { followerId: viewerId, followingId: post.authorId } } }),
        ]);
        viewerState = {
          liked: !!like,
          favorited: !!favorite,
          followedAuthor: !!follow,
        };
      }
      return formatFeedItem(post, viewerState);
    })
  );

  return {
    items,
    hasMore: skip + items.length < total,
    nextPage: skip + items.length < total ? page + 1 : null,
  };
}

/**
 * Get post detail.
 */
async function getPostDetail(postId, viewerId) {
  const prisma = getPrisma();

  const post = await prisma.communityPost.findUnique({
    where: { id: postId },
    include: {
      author: { select: { id: true, username: true, avatarUrl: true } },
      card: { select: { communitySafeContent: true, riskLevel: true } },
    },
  });

  if (!post || post.status === 'deleted' || (post.status !== 'published' && post.authorId !== viewerId)) {
    throw ApiError.notFound('Post not found');
  }

  // Increment view count once per viewer and post.
  const viewerKey = viewerId || `anonymous:${postId}`;
  const existingView = await prisma.postView.findUnique({
    where: { viewerKey_postId: { viewerKey, postId } },
  });
  if (!existingView) {
    const metrics = typeof post.metrics === 'object' ? post.metrics : {};
    await prisma.$transaction([
      prisma.postView.create({
        data: { userId: viewerId || null, postId, viewerKey },
      }),
      prisma.communityPost.update({
        where: { id: postId },
        data: { metrics: { ...metrics, views: (metrics.views || 0) + 1 } },
      }),
    ]).catch(() => {});
  }

  let viewerState = { liked: false, favorited: false, followedAuthor: false };
  if (viewerId) {
    const [like, favorite, follow] = await Promise.all([
      prisma.postLike.findUnique({ where: { userId_postId: { userId: viewerId, postId } } }),
      prisma.postFavorite.findUnique({ where: { userId_postId: { userId: viewerId, postId } } }),
      prisma.userFollow.findUnique({ where: { followerId_followingId: { followerId: viewerId, followingId: post.authorId } } }),
    ]);
    viewerState = {
      liked: !!like,
      favorited: !!favorite,
      followedAuthor: !!follow,
    };
  }

  return formatFeedItem(post, viewerState);
}

/**
 * Create a new post.
 */
async function createPost(authorId, data) {
  const prisma = getPrisma();

  const card = data.cardId ? await loadShareableCard(prisma, data.cardId, authorId) : null;
  const assessment = moderation.assessPostPayload({
    shareText: data.shareText,
    card,
  });
  const status = assessment.decision === 'approve' ? 'published' : 'hidden';
  const postId = `post_${randomUUID().slice(0, 12)}`;

  const post = await prisma.communityPost.create({
    data: {
      id: postId,
      authorId,
      cardId: data.cardId || null,
      shareText: data.shareText.trim(),
      coverImageUrl: data.coverImageUrl || null,
      tabTags: card?.session?.tag ? [card.session.tag, 'reflection'] : [],
      status,
      metrics: { likes: 0, favorites: 0, views: 0, comments: 0 },
    },
    include: {
      author: { select: { id: true, username: true, avatarUrl: true } },
      card: { select: { communitySafeContent: true, riskLevel: true } },
    },
  });

  await moderation.recordAssessment('community_post', post.id, assessment);

  logger.info({ postId, authorId }, 'Post created');

  return {
    ...formatFeedItem(post, { liked: false, favorited: false, followedAuthor: false }),
    moderation: {
      decision: assessment.decision,
      riskLevel: assessment.riskLevel,
      categories: assessment.categories,
      reason: assessment.reason,
    },
  };
}

/**
 * Get comments for a post.
 */
async function getComments(postId, page = 1, pageSize = 20) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  const [comments, total] = await Promise.all([
    prisma.comment.findMany({
      where: { postId, status: 'visible' },
      orderBy: { createdAt: 'asc' },
      skip,
      take: pageSize,
      include: {
        author: { select: { id: true, username: true, avatarUrl: true } },
      },
    }),
    prisma.comment.count({ where: { postId, status: 'visible' } }),
  ]);

  return {
    items: comments.map((c) => ({
      id: c.id,
      postId: c.postId,
      authorId: c.authorId,
      authorUsername: c.author.username,
      authorAvatarUrl: c.author.avatarUrl,
      parentId: c.parentId,
      text: c.text,
      createdAt: c.createdAt,
    })),
    hasMore: skip + comments.length < total,
    nextPage: skip + comments.length < total ? page + 1 : null,
  };
}

/**
 * Add a comment to a post.
 */
async function createComment(postId, authorId, text, parentId) {
  const prisma = getPrisma();

  // Verify post exists
  const post = await prisma.communityPost.findUnique({ where: { id: postId } });
  if (!post || post.status === 'deleted') {
    throw ApiError.notFound('Post not found');
  }

  const assessment = moderation.assessText(text);
  const status = assessment.decision === 'approve' ? 'visible' : 'hidden';
  const comment = await prisma.comment.create({
    data: { postId, authorId, text: text.trim(), parentId: parentId || null, status },
    include: {
      author: { select: { id: true, username: true, avatarUrl: true } },
    },
  });

  // Update comment count
  if (status === 'visible') {
    const metrics = typeof post.metrics === 'object' ? post.metrics : {};
    await prisma.communityPost.update({
      where: { id: postId },
      data: { metrics: { ...metrics, comments: (metrics.comments || 0) + 1 } },
    });
  }

  await moderation.recordAssessment('comment', comment.id, assessment);

  if (post.authorId !== authorId && status === 'visible') {
    await notificationService.createNotification(post.authorId, {
      type: 'interaction',
      title: `${comment.author.username || '有人'} 评论了你的帖子`,
      body: comment.text.slice(0, 80),
      data: { targetId: postId, targetType: 'post', commentId: comment.id },
    }).catch(() => {});
  }

  logger.info({ postId, authorId, commentId: comment.id }, 'Comment created');

  return {
    id: comment.id,
    postId: comment.postId,
    authorId: comment.authorId,
    authorUsername: comment.author.username,
    authorAvatarUrl: comment.author.avatarUrl,
    parentId: comment.parentId,
    text: comment.text,
    createdAt: comment.createdAt,
  };
}

/**
 * Like a post (idempotent).
 */
async function likePost(postId, userId) {
  const prisma = getPrisma();

  const post = await ensurePublishedPost(prisma, postId);

  const existing = await prisma.postLike.findUnique({
    where: { userId_postId: { userId, postId } },
  });

  if (!existing) {
    await prisma.postLike.create({ data: { userId, postId } });

    // Update metrics
    const metrics = typeof post.metrics === 'object' ? post.metrics : {};
    await prisma.communityPost.update({
      where: { id: postId },
      data: { metrics: { ...metrics, likes: (metrics.likes || 0) + 1 } },
    });

    if (post.authorId !== userId) {
      await notificationService.createNotification(post.authorId, {
        type: 'interaction',
        title: '有人喜欢了你的帖子',
        body: '',
        data: { targetId: postId, targetType: 'post' },
      }).catch(() => {});
    }
  }

  return { liked: true };
}

/**
 * Unlike a post (idempotent).
 */
async function unlikePost(postId, userId) {
  const prisma = getPrisma();

  const existing = await prisma.postLike.findUnique({
    where: { userId_postId: { userId, postId } },
  });

  if (existing) {
    await prisma.postLike.delete({ where: { id: existing.id } });

    const post = await prisma.communityPost.findUnique({ where: { id: postId } });
    if (post) {
      const metrics = typeof post.metrics === 'object' ? post.metrics : {};
      await prisma.communityPost.update({
        where: { id: postId },
        data: { metrics: { ...metrics, likes: Math.max(0, (metrics.likes || 0) - 1) } },
      });
    }
  }

  return { liked: false };
}

/**
 * Favorite a post (idempotent).
 */
async function favoritePost(postId, userId) {
  const prisma = getPrisma();

  const post = await ensurePublishedPost(prisma, postId);

  const existing = await prisma.postFavorite.findUnique({
    where: { userId_postId: { userId, postId } },
  });

  if (!existing) {
    await prisma.postFavorite.create({ data: { userId, postId } });

    const metrics = typeof post.metrics === 'object' ? post.metrics : {};
    await prisma.communityPost.update({
      where: { id: postId },
      data: { metrics: { ...metrics, favorites: (metrics.favorites || 0) + 1 } },
    });

    if (post.authorId !== userId) {
      await notificationService.createNotification(post.authorId, {
        type: 'interaction',
        title: '有人收藏了你的帖子',
        body: '',
        data: { targetId: postId, targetType: 'post' },
      }).catch(() => {});
    }
  }

  return { favorited: true };
}

/**
 * Unfavorite a post (idempotent).
 */
async function unfavoritePost(postId, userId) {
  const prisma = getPrisma();

  const existing = await prisma.postFavorite.findUnique({
    where: { userId_postId: { userId, postId } },
  });

  if (existing) {
    await prisma.postFavorite.delete({ where: { id: existing.id } });

    const post = await prisma.communityPost.findUnique({ where: { id: postId } });
    if (post) {
      const metrics = typeof post.metrics === 'object' ? post.metrics : {};
      await prisma.communityPost.update({
        where: { id: postId },
        data: { metrics: { ...metrics, favorites: Math.max(0, (metrics.favorites || 0) - 1) } },
      });
    }
  }

  return { favorited: false };
}

/**
 * Report a post.
 */
async function reportPost(postId, reporterId, reason, detail) {
  const prisma = getPrisma();

  // Idempotent per user+post+reason
  const existing = await prisma.postReport.findUnique({
    where: { reporterId_postId_reason: { reporterId, postId, reason } },
  });

  if (existing) {
    return { reported: true, reportId: existing.id };
  }

  const report = await prisma.postReport.create({
    data: { reporterId, postId, reason, detail },
  });

  logger.info({ postId, reporterId, reason }, 'Post reported');

  return { reported: true, reportId: report.id };
}

/**
 * Hide a post (reduce recommendations).
 */
async function hidePost(postId, userId) {
  const prisma = getPrisma();
  await ensurePublishedPost(prisma, postId);
  await prisma.postHide.upsert({
    where: { userId_postId: { userId, postId } },
    update: {},
    create: { userId, postId },
  });
  logger.info({ postId, userId }, 'Post hidden for user');
  return { hidden: true };
}

/**
 * Get author profile.
 */
async function getAuthorProfile(authorId, viewerId) {
  const prisma = getPrisma();

  const user = await prisma.user.findUnique({
    where: { id: authorId },
    select: { id: true, username: true, bio: true, avatarUrl: true },
  });

  if (!user || user.status === 'deleted') {
    throw ApiError.notFound('Author not found');
  }

  const [postCount, followerCount, followingCount] = await Promise.all([
    prisma.communityPost.count({ where: { authorId, status: 'published' } }),
    prisma.userFollow.count({ where: { followingId: authorId } }),
    prisma.userFollow.count({ where: { followerId: authorId } }),
  ]);

  let viewerState = { followed: false, blocked: false };
  if (viewerId) {
    const [follow, block] = await Promise.all([
      prisma.userFollow.findUnique({ where: { followerId_followingId: { followerId: viewerId, followingId: authorId } } }),
      prisma.userBlock.findUnique({ where: { blockerId_blockedUserId: { blockerId: viewerId, blockedUserId: authorId } } }),
    ]);
    viewerState = { followed: !!follow, blocked: !!block };
  }

  return {
    id: user.id,
    username: user.username,
    bio: user.bio,
    avatarUrl: user.avatarUrl,
    postCount,
    followerCount,
    followingCount,
    viewerState,
  };
}

/**
 * Follow an author (idempotent).
 */
async function followAuthor(followerId, followingId) {
  const prisma = getPrisma();

  if (followerId === followingId) {
    throw ApiError.badRequest('Cannot follow yourself');
  }

  const existing = await prisma.userFollow.findUnique({
    where: { followerId_followingId: { followerId, followingId } },
  });

  if (!existing) {
    await prisma.userFollow.create({ data: { followerId, followingId } });
    await notificationService.createNotification(followingId, {
      type: 'interaction',
      title: '你有新的关注者',
      body: '',
      data: { targetId: followerId, targetType: 'user' },
    }).catch(() => {});
  }

  return { followed: true };
}

/**
 * Unfollow an author (idempotent).
 */
async function unfollowAuthor(followerId, followingId) {
  const prisma = getPrisma();

  const existing = await prisma.userFollow.findUnique({
    where: { followerId_followingId: { followerId, followingId } },
  });

  if (existing) {
    await prisma.userFollow.delete({ where: { id: existing.id } });
  }

  return { followed: false };
}

/**
 * Block a user.
 */
async function blockUser(blockerId, blockedUserId) {
  const prisma = getPrisma();

  const existing = await prisma.userBlock.findUnique({
    where: { blockerId_blockedUserId: { blockerId, blockedUserId } },
  });

  if (!existing) {
    await prisma.userBlock.create({ data: { blockerId, blockedUserId } });
  }

  return { blocked: true };
}

/**
 * Unblock a user.
 */
async function unblockUser(blockerId, blockedUserId) {
  const prisma = getPrisma();

  const existing = await prisma.userBlock.findUnique({
    where: { blockerId_blockedUserId: { blockerId, blockedUserId } },
  });

  if (existing) {
    await prisma.userBlock.delete({ where: { id: existing.id } });
  }

  return { blocked: false };
}

/**
 * Search posts, users, and activities.
 */
async function search(query, type, page, pageSize) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  const results = [];

  if (type === 'all' || type === 'post') {
    const posts = await prisma.communityPost.findMany({
      where: {
        status: 'published',
        shareText: { contains: query, mode: 'insensitive' },
      },
      skip,
      take: pageSize,
      include: {
        author: { select: { id: true, username: true, avatarUrl: true } },
        card: { select: { communitySafeContent: true, riskLevel: true } },
      },
    });
    results.push(...posts.map((p) => ({ type: 'post', ...formatFeedItem(p, {}) })));
  }

  if (type === 'all' || type === 'user') {
    const users = await prisma.user.findMany({
      where: {
        status: 'active',
        username: { contains: query, mode: 'insensitive' },
      },
      skip,
      take: pageSize,
    });
    results.push(...users.map((u) => ({ type: 'user', id: u.id, username: u.username, avatarUrl: u.avatarUrl })));
  }

  if (type === 'all' || type === 'activity') {
    const activities = await prisma.activity.findMany({
      where: {
        OR: [
          { title: { contains: query, mode: 'insensitive' } },
          { description: { contains: query, mode: 'insensitive' } },
        ],
      },
      skip,
      take: pageSize,
    });
    results.push(...activities.map((activity) => ({
      type: 'activity',
      id: activity.id,
      title: activity.title,
      description: activity.description,
      imageUrl: activity.imageUrl,
      status: activity.status,
      startAt: activity.startAt,
    })));
  }

  return {
    items: results,
    hasMore: results.length >= pageSize,
    nextPage: results.length >= pageSize ? page + 1 : null,
  };
}

// ─────────────── Helpers ───────────────

function formatFeedItem(post, viewerState) {
  const metrics = typeof post.metrics === 'object' ? post.metrics : {};
  const safeCard = post.card?.communitySafeContent || null;
  return {
    id: post.id,
    cardId: post.cardId,
    shareText: post.shareText,
    coverImageUrl: post.coverImageUrl,
    cardPreview: safeCard
      ? {
          summary: safeCard.summary || '',
          body: safeCard.body || '',
          focusPoints: safeCard.focusPoints || [],
          riskLevel: post.card.riskLevel,
        }
      : null,
    authorId: post.authorId,
    authorUsername: post.author?.username,
    authorAvatarUrl: post.author?.avatarUrl,
    createdAt: post.createdAt,
    status: post.status,
    metrics: {
      likes: metrics.likes || 0,
      favorites: metrics.favorites || 0,
      views: metrics.views || 0,
      comments: metrics.comments || 0,
    },
    viewerState,
  };
}

async function loadShareableCard(prisma, cardId, authorId) {
  const card = await prisma.interpretationCard.findUnique({
    where: { id: cardId },
    include: { session: { select: { userId: true, tag: true } } },
  });

  if (!card) {
    throw ApiError.notFound('Interpretation card not found');
  }

  if (card.session.userId !== authorId) {
    throw ApiError.forbidden('Cannot share another user card');
  }

  const safeContent = card.communitySafeContent;
  if (!safeContent || typeof safeContent !== 'object' || (!safeContent.summary && !safeContent.body)) {
    throw ApiError.badRequest('Card does not have community-safe content');
  }

  return card;
}

async function ensurePublishedPost(prisma, postId) {
  const post = await prisma.communityPost.findUnique({ where: { id: postId } });
  if (!post || post.status !== 'published') {
    throw ApiError.notFound('Post not found');
  }
  return post;
}

module.exports = {
  getFeed,
  getPostDetail,
  createPost,
  getComments,
  createComment,
  likePost,
  unlikePost,
  favoritePost,
  unfavoritePost,
  reportPost,
  hidePost,
  getAuthorProfile,
  followAuthor,
  unfollowAuthor,
  blockUser,
  unblockUser,
  search,
};

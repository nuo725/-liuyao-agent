// Anonymous Identity Service (IDENTITY-001, COMMUNITY-013)
// Manages anonymous profiles for privacy-preserving community participation.

const { randomUUID } = require('crypto');
const { getPrisma } = require('../../db/prisma');
const { createLogger } = require('../../shared/logger');

const logger = createLogger('anonymous-service');

// Adjective + Noun pools for generating anonymous names
const ADJECTIVES = ['安静的', '勇敢的', '温柔的', '自由的', '沉思的', '明亮的', '平静的', '坚定的', '温暖的', '清新的'];
const NOUNS = ['星辰', '月光', '微风', '山峦', '海洋', '森林', '溪流', '云朵', '落叶', '晨曦'];

/**
 * Get or create anonymous profile for a user.
 */
async function getOrCreateProfile(userId) {
  const prisma = getPrisma();

  let profile = await prisma.anonymousProfile.findUnique({
    where: { userId },
  });

  if (!profile) {
    const displayName = generateAnonymousName();
    const avatarSeed = randomUUID().slice(0, 8);

    profile = await prisma.anonymousProfile.create({
      data: {
        userId,
        displayName,
        avatarSeed,
        bio: '',
      },
    });

    logger.info({ userId, displayName }, 'Anonymous profile created');
  }

  return formatProfile(profile);
}

/**
 * Update anonymous profile.
 */
async function updateProfile(userId, data) {
  const prisma = getPrisma();

  const profile = await prisma.anonymousProfile.upsert({
    where: { userId },
    update: {
      ...(data.displayName && { displayName: data.displayName }),
      ...(data.bio !== undefined && { bio: data.bio }),
    },
    create: {
      userId,
      displayName: data.displayName || generateAnonymousName(),
      avatarSeed: randomUUID().slice(0, 8),
      bio: data.bio || '',
    },
  });

  logger.info({ userId }, 'Anonymous profile updated');
  return formatProfile(profile);
}

/**
 * Create an anonymous post (hides real identity).
 */
async function createAnonymousPost(userId, data) {
  const prisma = getPrisma();

  // Get anonymous profile
  const anonProfile = await getOrCreateProfile(userId);

  // Create post with anonymous flag
  const postId = `post_${randomUUID().slice(0, 12)}`;

  const post = await prisma.communityPost.create({
    data: {
      id: postId,
      authorId: userId,
      cardId: data.cardId || null,
      shareText: data.shareText,
      coverImageUrl: data.coverImageUrl || null,
      tabTags: data.tabTags || [],
      status: 'published',
      metrics: { likes: 0, favorites: 0, views: 0, comments: 0 },
      // Store anonymous metadata in a way the frontend can use
    },
  });

  logger.info({ postId, userId, anonymousName: anonProfile.displayName }, 'Anonymous post created');

  return {
    id: post.id,
    shareText: post.shareText,
    anonymousAuthor: {
      displayName: anonProfile.displayName,
      avatarSeed: anonProfile.avatarSeed,
    },
    createdAt: post.createdAt,
  };
}

/**
 * Get anonymous author info for a post.
 */
async function getAnonymousAuthor(userId) {
  const prisma = getPrisma();

  const profile = await prisma.anonymousProfile.findUnique({
    where: { userId },
  });

  if (!profile) {
    return {
      displayName: '匿名用户',
      avatarSeed: 'default',
    };
  }

  return {
    displayName: profile.displayName,
    avatarSeed: profile.avatarSeed,
  };
}

// ─────────────── Helpers ───────────────

function generateAnonymousName() {
  const adj = ADJECTIVES[Math.floor(Math.random() * ADJECTIVES.length)];
  const noun = NOUNS[Math.floor(Math.random() * NOUNS.length)];
  return `${adj}${noun}`;
}

function formatProfile(profile) {
  return {
    userId: profile.userId,
    displayName: profile.displayName,
    avatarSeed: profile.avatarSeed,
    bio: profile.bio,
    createdAt: profile.createdAt,
  };
}

module.exports = {
  getOrCreateProfile,
  updateProfile,
  createAnonymousPost,
  getAnonymousAuthor,
};

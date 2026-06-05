// Structured Case Retrieval Service (CASE-001)
// Allows searching through public safe card content with question type and pattern filtering.
// Only retrieves community-safe versions, never exposes private content.

const { getPrisma } = require('../../db/prisma');

/**
 * Search cases by question type, pattern structure, and keywords.
 */
async function searchCases(filters, page = 1, pageSize = 20) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  // Build where clause
  const where = {};

  // Filter by tag (question type)
  if (filters.tag) {
    where.session = { tag: filters.tag };
  }

  // Filter by pattern lines (hexagram structure)
  if (filters.lines) {
    where.session = {
      ...where.session,
      path: ['pattern', 'lines'],
      equals: filters.lines,
    };
  }

  // Filter by risk level
  if (filters.riskLevel) {
    where.riskLevel = filters.riskLevel;
  }

  // Only show completed sessions with safe content
  where.communitySafeContent = { not: null };
  where.session = {
    ...where.session,
    status: 'completed',
  };

  // Search in safe content summary/body
  if (filters.keyword) {
    where.OR = [
      { communitySafeContent: { path: ['summary'], string_contains: filters.keyword } },
      { communitySafeContent: { path: ['body'], string_contains: filters.keyword } },
    ];
  }

  const [cards, total] = await Promise.all([
    prisma.interpretationCard.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: pageSize,
      include: {
        session: {
          select: {
            id: true,
            question: true,
            tag: true,
            pattern: true,
            createdAt: true,
          },
        },
      },
    }),
    prisma.interpretationCard.count({ where }),
  ]);

  return {
    items: cards.map((card) => formatCase(card)),
    hasMore: skip + cards.length < total,
    nextPage: skip + cards.length < total ? page + 1 : null,
    total,
  };
}

/**
 * Get a single case by ID (public safe version only).
 */
async function getCase(caseId) {
  const prisma = getPrisma();

  const card = await prisma.interpretationCard.findUnique({
    where: { id: caseId },
    include: {
      session: {
        select: {
          id: true,
          question: true,
          tag: true,
          pattern: true,
          createdAt: true,
        },
      },
    },
  });

  if (!card || !card.communitySafeContent) {
    return null;
  }

  return formatCase(card);
}

/**
 * Get cases by hexagram pattern (same structure).
 */
async function getCasesByPattern(lines, movingLines, page = 1, pageSize = 20) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  // Find sessions with matching pattern
  const sessions = await prisma.ritualSession.findMany({
    where: {
      status: 'completed',
      pattern: {
        equals: { lines, movingLines },
      },
    },
    select: { id: true },
    skip,
    take: pageSize,
  });

  const sessionIds = sessions.map((s) => s.id);

  const cards = await prisma.interpretationCard.findMany({
    where: {
      sessionId: { in: sessionIds },
      communitySafeContent: { not: null },
    },
    include: {
      session: {
        select: {
          id: true,
          question: true,
          tag: true,
          pattern: true,
          createdAt: true,
        },
      },
    },
  });

  return {
    items: cards.map((card) => formatCase(card)),
    pattern: { lines, movingLines },
    count: cards.length,
  };
}

/**
 * Get popular cases (most viewed/liked).
 */
async function getPopularCases(tag, page = 1, pageSize = 20) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  // Find posts with cards that have high engagement
  const where = {
    status: 'published',
    cardId: { not: null },
  };

  if (tag) {
    where.tabTags = { has: tag };
  }

  const posts = await prisma.communityPost.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: 100, // Fetch more for sorting
    select: {
      id: true,
      cardId: true,
      metrics: true,
      shareText: true,
      createdAt: true,
    },
  });

  // Sort by engagement score
  const scored = posts.map((post) => {
    const metrics = post.metrics || {};
    const score = (metrics.likes || 0) + (metrics.comments || 0) * 2 + (metrics.favorites || 0) * 1.5;
    return { post, score };
  }).sort((a, b) => b.score - a.score);

  // Get cards for top posts
  const topCardIds = scored.slice(skip, skip + pageSize).map((s) => s.post.cardId).filter(Boolean);

  const cards = await prisma.interpretationCard.findMany({
    where: { id: { in: topCardIds } },
    include: {
      session: {
        select: {
          id: true,
          question: true,
          tag: true,
          pattern: true,
          createdAt: true,
        },
      },
    },
  });

  return {
    items: cards.map((card) => formatCase(card)),
    hasMore: skip + cards.length < scored.length,
    nextPage: skip + cards.length < scored.length ? page + 1 : null,
  };
}

/**
 * Get tag statistics (distribution of question types).
 */
async function getTagStats() {
  const prisma = getPrisma();

  const stats = await prisma.ritualSession.groupBy({
    by: ['tag'],
    where: { status: 'completed' },
    _count: { id: true },
  });

  return stats.map((s) => ({
    tag: s.tag,
    count: s._count.id,
  }));
}

// ─────────────── Helpers ───────────────

function formatCase(card) {
  const safeContent = card.communitySafeContent || {};
  const session = card.session || {};

  return {
    id: card.id,
    sessionId: session.id,
    question: session.question,
    tag: session.tag,
    pattern: session.pattern,
    summary: safeContent.summary,
    body: safeContent.body,
    focusPoints: safeContent.focusPoints || [],
    createdAt: card.createdAt,
  };
}

module.exports = {
  searchCases,
  getCase,
  getCasesByPattern,
  getPopularCases,
  getTagStats,
};

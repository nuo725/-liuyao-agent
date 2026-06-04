// Ritual Module - Business Logic Service
// Handles ritual sessions, patterns, interpretation cards, and follow-up messages.
// NOTE: Does NOT generate interpretations - that's the independent Agent service.

const { randomUUID } = require('crypto');
const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const { createLogger } = require('../../shared/logger');
const creditService = require('../credits/service');

const logger = createLogger('ritual-service');

/**
 * Create a new ritual session (perform divination).
 */
async function perform(userId, question, tag, lines, movingLines, idempotencyKey) {
  const prisma = getPrisma();

  await creditService.consume(userId, 'cast', 1, idempotencyKey ? `ritual:${idempotencyKey}` : null);

  const sessionId = `ritual_${randomUUID().slice(0, 12)}`;
  const today = new Date().toISOString().split('T')[0];

  const [session] = await prisma.$transaction([
    prisma.ritualSession.create({
      data: {
        id: sessionId,
        userId,
        question,
        tag,
        pattern: { lines, movingLines },
        status: 'active',
        riskLevel: 'low',
      },
    }),
    prisma.dailyCompletion.upsert({
      where: { userId_dateKey: { userId, dateKey: today } },
      update: { completed: true },
      create: { userId, dateKey: today, completed: true },
    }),
  ]);

  logger.info({ sessionId, userId, tag }, 'Ritual session created');

  return {
    sessionId: session.id,
    question: session.question,
    tag: session.tag,
    pattern: session.pattern,
    status: session.status,
    createdAt: session.createdAt,
  };
}

/**
 * Get ritual session by ID.
 */
async function getSession(sessionId, userId) {
  const prisma = getPrisma();

  const session = await prisma.ritualSession.findUnique({
    where: { id: sessionId },
    include: { interpretationCard: true },
  });

  if (!session) {
    throw ApiError.notFound('Session not found');
  }

  // Check ownership (allow if same user or if session is public)
  if (session.userId !== userId) {
    throw ApiError.forbidden('Not your session');
  }

  return formatSession(session);
}

/**
 * Get session preview (for first-time users).
 */
async function getPreview(sessionId) {
  const prisma = getPrisma();

  const session = await prisma.ritualSession.findUnique({
    where: { id: sessionId },
    include: { interpretationCard: true },
  });

  if (!session) {
    throw ApiError.notFound('Session not found');
  }

  if (!session.interpretationCard) {
    return {
      sessionId: session.id,
      pattern: session.pattern,
      card: null,
      message: 'Interpretation not yet available',
    };
  }

  const card = session.interpretationCard;
  const safeContent = card.communitySafeContent;

  return {
    sessionId: session.id,
    pattern: session.pattern,
    card: {
      summary: safeContent.summary,
      body: safeContent.body,
      focusPoints: safeContent.focusPoints || [],
    },
  };
}

/**
 * Get full interpretation (requires auth).
 */
async function getFullInterpretation(sessionId, userId) {
  const prisma = getPrisma();

  const session = await prisma.ritualSession.findUnique({
    where: { id: sessionId },
    include: { interpretationCard: true },
  });

  if (!session) {
    throw ApiError.notFound('Session not found');
  }

  if (session.userId !== userId) {
    throw ApiError.forbidden('Not your session');
  }

  if (!session.interpretationCard) {
    return {
      sessionId: session.id,
      pattern: session.pattern,
      card: null,
      message: 'Interpretation not yet available',
    };
  }

  const card = session.interpretationCard;
  const privateContent = card.privateContent;

  return {
    sessionId: session.id,
    pattern: session.pattern,
    card: {
      summary: privateContent.summary,
      body: privateContent.body,
      followupDirections: privateContent.followupDirections || [],
      needsClarification: privateContent.needsClarification || false,
      microActions: privateContent.microActions || [],
    },
  };
}

/**
 * Add a follow-up message (user question).
 */
async function addFollowup(sessionId, userId, content, idempotencyKey) {
  const prisma = getPrisma();

  const session = await prisma.ritualSession.findUnique({
    where: { id: sessionId },
  });

  if (!session) {
    throw ApiError.notFound('Session not found');
  }

  if (session.userId !== userId) {
    throw ApiError.forbidden('Not your session');
  }

  if (session.status !== 'active') {
    throw ApiError.conflict('Session is not active');
  }

  await creditService.consume(userId, 'followup', 1, idempotencyKey ? `followup:${idempotencyKey}` : null);

  // Save user message
  const userMessage = await prisma.followupMessage.create({
    data: {
      sessionId,
      type: 'question',
      content,
    },
  });

  logger.info({ sessionId, userId }, 'Follow-up question added');

  // NOTE: The actual answer generation is handled by the independent Agent service.
  // This just stores the question. The answer will be added via a separate endpoint
  // or by the Agent service callback.

  return {
    id: userMessage.id,
    type: userMessage.type,
    content: userMessage.content,
    createdAt: userMessage.createdAt,
  };
}

/**
 * Get chat history for a session.
 */
async function getChatHistory(sessionId, userId) {
  const prisma = getPrisma();

  const session = await prisma.ritualSession.findUnique({
    where: { id: sessionId },
  });

  if (!session) {
    throw ApiError.notFound('Session not found');
  }

  if (session.userId !== userId) {
    throw ApiError.forbidden('Not your session');
  }

  const messages = await prisma.followupMessage.findMany({
    where: { sessionId },
    orderBy: { createdAt: 'asc' },
  });

  return {
    messages: messages.map((m) => ({
      id: m.id,
      type: m.type,
      content: m.content,
      createdAt: m.createdAt,
    })),
  };
}

/**
 * Get daily completion status.
 */
async function getCompletionToday(userId) {
  const prisma = getPrisma();
  const today = new Date().toISOString().split('T')[0];

  const completion = await prisma.dailyCompletion.findUnique({
    where: { userId_dateKey: { userId, dateKey: today } },
  });

  const sessions = await prisma.ritualSession.findMany({
    where: {
      userId,
      createdAt: {
        gte: new Date(today + 'T00:00:00.000Z'),
        lt: new Date(today + 'T23:59:59.999Z'),
      },
    },
  });

  return {
    completed: !!completion?.completed || sessions.length > 0,
    dateKey: today,
    count: sessions.length,
  };
}

/**
 * Store interpretation card (called by Agent service or mock).
 */
async function storeInterpretation(sessionId, privateContent, communitySafeContent, riskLevel = 'low') {
  const prisma = getPrisma();

  const card = await prisma.interpretationCard.upsert({
    where: { sessionId },
    update: {
      privateContent,
      communitySafeContent,
      riskLevel,
    },
    create: {
      sessionId,
      privateContent,
      communitySafeContent,
      riskLevel,
    },
  });

  // Mark session as completed
  await prisma.ritualSession.update({
    where: { id: sessionId },
    data: { status: 'completed' },
  });

  logger.info({ sessionId }, 'Interpretation card stored');

  return card;
}

/**
 * Store an agent answer (called by Agent service callback).
 */
async function storeAnswer(sessionId, content) {
  const prisma = getPrisma();

  const message = await prisma.followupMessage.create({
    data: {
      sessionId,
      type: 'answer',
      content,
    },
  });

  return message;
}

async function saveEmotionCalibration(sessionId, userId, data) {
  const prisma = getPrisma();
  const session = await prisma.ritualSession.findUnique({
    where: { id: sessionId },
    select: { id: true, userId: true },
  });

  if (!session) {
    throw ApiError.notFound('Session not found');
  }
  if (session.userId !== userId) {
    throw ApiError.forbidden('Not your session');
  }

  const calibration = await prisma.emotionCalibration.create({
    data: {
      userId,
      sessionId,
      feedback: data.feedback || null,
      customText: data.customText || null,
    },
  });

  return {
    id: calibration.id,
    sessionId: calibration.sessionId,
    feedback: calibration.feedback,
    customText: calibration.customText,
    createdAt: calibration.createdAt,
  };
}

async function getPeriodicReview(userId, days = 30) {
  const prisma = getPrisma();
  const to = new Date();
  const from = new Date(to);
  from.setDate(from.getDate() - days);

  const [sessions, calibrations] = await Promise.all([
    prisma.ritualSession.findMany({
      where: {
        userId,
        createdAt: { gte: from, lte: to },
      },
      include: { interpretationCard: true },
      orderBy: { createdAt: 'desc' },
    }),
    prisma.emotionCalibration.findMany({
      where: {
        userId,
        createdAt: { gte: from, lte: to },
      },
      orderBy: { createdAt: 'desc' },
    }),
  ]);

  const tagDistribution = countBy(sessions, (session) => session.tag);
  const statusDistribution = countBy(sessions, (session) => session.status);
  const riskDistribution = countBy(sessions, (session) => session.riskLevel);
  const feedbackDistribution = countBy(calibrations, (calibration) => calibration.feedback || 'custom_only');
  const focusPointCounts = new Map();

  for (const session of sessions) {
    const points = session.interpretationCard?.privateContent?.focusPoints
      || session.interpretationCard?.communitySafeContent?.focusPoints
      || [];
    if (!Array.isArray(points)) continue;
    for (const point of points) {
      const key = String(point).trim();
      if (key) {
        focusPointCounts.set(key, (focusPointCounts.get(key) || 0) + 1);
      }
    }
  }

  const recurringThemes = [...focusPointCounts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([text, count]) => ({ text, count }));

  return {
    period: {
      days,
      from: from.toISOString(),
      to: to.toISOString(),
    },
    sessionCount: sessions.length,
    completedCount: statusDistribution.completed || 0,
    tagDistribution,
    statusDistribution,
    riskDistribution,
    calibration: {
      count: calibrations.length,
      feedbackDistribution,
      latest: calibrations.slice(0, 5).map((calibration) => ({
        id: calibration.id,
        sessionId: calibration.sessionId,
        feedback: calibration.feedback,
        customText: calibration.customText,
        createdAt: calibration.createdAt,
      })),
    },
    recurringThemes,
    reviewText: buildReviewText(sessions.length, tagDistribution, feedbackDistribution, recurringThemes),
  };
}

// ─────────────── Helpers ───────────────

function formatSession(session) {
  return {
    sessionId: session.id,
    question: session.question,
    tag: session.tag,
    pattern: session.pattern,
    status: session.status,
    riskLevel: session.riskLevel,
    card: session.interpretationCard
      ? {
          summary: session.interpretationCard.privateContent?.summary,
          body: session.interpretationCard.privateContent?.body,
          followupDirections: session.interpretationCard.privateContent?.followupDirections,
        }
      : null,
    createdAt: session.createdAt,
  };
}

function countBy(items, pickKey) {
  return items.reduce((result, item) => {
    const key = pickKey(item) || 'unknown';
    result[key] = (result[key] || 0) + 1;
    return result;
  }, {});
}

function buildReviewText(sessionCount, tagDistribution, feedbackDistribution, recurringThemes) {
  if (sessionCount === 0) {
    return '这段时间还没有新的仪式记录，可以先从一个具体问题开始。';
  }
  const topTag = Object.entries(tagDistribution).sort((a, b) => b[1] - a[1])[0]?.[0] || 'other';
  const resonance = feedbackDistribution.resonated || 0;
  const themeText = recurringThemes[0]?.text ? `，反复出现的关注点是「${recurringThemes[0].text}」` : '';
  return `最近你完成了 ${sessionCount} 次仪式，最常出现的主题是 ${topTag}${themeText}。已有 ${resonance} 次反馈显示解读与你的感受贴近，可继续观察它们在现实行动中的变化。`;
}

module.exports = {
  perform,
  getSession,
  getPreview,
  getFullInterpretation,
  addFollowup,
  getChatHistory,
  getCompletionToday,
  storeInterpretation,
  storeAnswer,
  saveEmotionCalibration,
  getPeriodicReview,
};

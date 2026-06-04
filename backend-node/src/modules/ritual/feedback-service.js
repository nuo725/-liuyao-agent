// Ritual Feedback Service (FEEDBACK-001, COMMUNITY-014)
// Allows users to provide follow-up feedback on their divination results.

const { randomUUID } = require('crypto');
const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const { createLogger } = require('../../shared/logger');

const logger = createLogger('feedback-service');

/**
 * Submit feedback on a ritual session.
 */
async function submitFeedback(userId, sessionId, data) {
  const prisma = getPrisma();

  // Verify session exists and belongs to user
  const session = await prisma.ritualSession.findUnique({
    where: { id: sessionId },
  });

  if (!session) {
    throw ApiError.notFound('Session not found');
  }

  if (session.userId !== userId) {
    throw ApiError.forbidden('Not your session');
  }

  // Create feedback
  const feedback = await prisma.ritualFeedback.create({
    data: {
      userId,
      sessionId,
      outcome: data.outcome,
      feeling: data.feeling,
      followUp: data.followUp || null,
    },
  });

  logger.info({ userId, sessionId, feedbackId: feedback.id }, 'Feedback submitted');

  return {
    id: feedback.id,
    sessionId: feedback.sessionId,
    outcome: feedback.outcome,
    feeling: feedback.feeling,
    followUp: feedback.followUp,
    createdAt: feedback.createdAt,
  };
}

/**
 * Get feedback history for a user.
 */
async function getFeedbackHistory(userId, page = 1, pageSize = 20) {
  const prisma = getPrisma();
  const skip = (page - 1) * pageSize;

  const [feedbacks, total] = await Promise.all([
    prisma.ritualFeedback.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip,
      take: pageSize,
      include: {
        session: {
          select: { id: true, question: true, tag: true },
        },
      },
    }),
    prisma.ritualFeedback.count({ where: { userId } }),
  ]);

  return {
    items: feedbacks.map((f) => ({
      id: f.id,
      sessionId: f.sessionId,
      question: f.session.question,
      tag: f.session.tag,
      outcome: f.outcome,
      feeling: f.feeling,
      followUp: f.followUp,
      createdAt: f.createdAt,
    })),
    hasMore: skip + feedbacks.length < total,
    nextPage: skip + feedbacks.length < total ? page + 1 : null,
  };
}

/**
 * Get feedback for a specific session.
 */
async function getSessionFeedback(sessionId, userId) {
  const prisma = getPrisma();

  const feedbacks = await prisma.ritualFeedback.findMany({
    where: { sessionId, userId },
    orderBy: { createdAt: 'desc' },
  });

  return feedbacks.map((f) => ({
    id: f.id,
    outcome: f.outcome,
    feeling: f.feeling,
    followUp: f.followUp,
    createdAt: f.createdAt,
  }));
}

/**
 * Create a feedback post (share feedback to community).
 */
async function createFeedbackPost(userId, feedbackId, shareText) {
  const prisma = getPrisma();

  const feedback = await prisma.ritualFeedback.findUnique({
    where: { id: feedbackId },
    include: { session: true },
  });

  if (!feedback) {
    throw ApiError.notFound('Feedback not found');
  }

  if (feedback.userId !== userId) {
    throw ApiError.forbidden('Not your feedback');
  }

  // Create community post linking to the feedback
  const postId = `post_${randomUUID().slice(0, 12)}`;

  const post = await prisma.communityPost.create({
    data: {
      id: postId,
      authorId: userId,
      shareText: shareText || `分享一下我的后续感受：${feedback.feeling}`,
      tabTags: [feedback.session.tag, 'feedback'],
      status: 'published',
      metrics: { likes: 0, favorites: 0, views: 0, comments: 0 },
    },
  });

  logger.info({ postId, userId, feedbackId }, 'Feedback post created');

  return {
    id: post.id,
    shareText: post.shareText,
    createdAt: post.createdAt,
  };
}

/**
 * Get periodic review data (weekly/monthly summary).
 */
async function getPeriodicReview(userId, days = 30) {
  const prisma = getPrisma();

  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  // Get sessions in period
  const sessions = await prisma.ritualSession.findMany({
    where: {
      userId,
      createdAt: { gte: startDate },
    },
    orderBy: { createdAt: 'desc' },
    include: { feedbacks: true },
  });

  // Get feedbacks in period
  const feedbacks = await prisma.ritualFeedback.findMany({
    where: {
      userId,
      createdAt: { gte: startDate },
    },
    orderBy: { createdAt: 'desc' },
  });

  // Aggregate by tag
  const tagCounts = {};
  for (const session of sessions) {
    tagCounts[session.tag] = (tagCounts[session.tag] || 0) + 1;
  }

  // Find most common tag
  const topTag = Object.entries(tagCounts).sort((a, b) => b[1] - a[1])[0];

  return {
    period: { days, startDate, endDate: new Date() },
    summary: {
      totalSessions: sessions.length,
      totalFeedbacks: feedbacks.length,
      tagDistribution: tagCounts,
      topTag: topTag ? { tag: topTag[0], count: topTag[1] } : null,
    },
    recentSessions: sessions.slice(0, 5).map((s) => ({
      id: s.id,
      question: s.question,
      tag: s.tag,
      hasFeedback: s.feedbacks.length > 0,
      createdAt: s.createdAt,
    })),
    recentFeedbacks: feedbacks.slice(0, 5).map((f) => ({
      id: f.id,
      sessionId: f.sessionId,
      outcome: f.outcome,
      feeling: f.feeling,
      createdAt: f.createdAt,
    })),
  };
}

module.exports = {
  submitFeedback,
  getFeedbackHistory,
  getSessionFeedback,
  createFeedbackPost,
  getPeriodicReview,
};

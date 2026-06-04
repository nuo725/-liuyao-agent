// Analytics Module - Business Logic Service

const { getPrisma } = require('../../db/prisma');

const WMRU_EVENTS = [
  'ritual_completed',
  'post_published',
  'comment_created',
  'share_published',
  'match_unlocked',
  'activity_joined',
  'feedback_submitted',
];

async function ingestEvent(userId, data) {
  const prisma = getPrisma();
  const event = await prisma.analyticsEvent.create({
    data: {
      userId,
      eventName: data.eventName,
      payload: data.payload || {},
      clientInfo: data.client || null,
      occurredAt: data.occurredAt ? new Date(data.occurredAt) : new Date(),
    },
  });

  return {
    eventId: event.id,
    accepted: true,
  };
}

async function calculateWmru(weekKey = currentWeekKey()) {
  const prisma = getPrisma();
  const { start, end } = weekRange(weekKey);
  const events = await prisma.analyticsEvent.findMany({
    where: {
      userId: { not: null },
      eventName: { in: WMRU_EVENTS },
      occurredAt: { gte: start, lt: end },
    },
    select: { userId: true, eventName: true },
  });

  const users = new Set(events.map((event) => event.userId).filter(Boolean));
  const eventCounts = {};
  for (const event of events) {
    eventCounts[event.eventName] = (eventCounts[event.eventName] || 0) + 1;
  }

  const metric = await prisma.weeklyMetric.upsert({
    where: { weekKey },
    update: {
      wmru: users.size,
      payload: { eventCounts, calculatedAt: new Date().toISOString() },
    },
    create: {
      weekKey,
      wmru: users.size,
      payload: { eventCounts, calculatedAt: new Date().toISOString() },
    },
  });

  return formatWmru(metric);
}

async function getWmru(weekKey = currentWeekKey()) {
  const prisma = getPrisma();
  const metric = await prisma.weeklyMetric.findUnique({ where: { weekKey } });
  return metric ? formatWmru(metric) : calculateWmru(weekKey);
}

async function getSafetyMetrics(weekKey = currentWeekKey()) {
  const prisma = getPrisma();
  const { start, end } = weekRange(weekKey);

  const [assessments, reports, moderationRecords] = await Promise.all([
    prisma.safetyAssessment.findMany({
      where: { createdAt: { gte: start, lt: end } },
      select: { riskLevel: true, decision: true },
    }),
    prisma.postReport.findMany({
      where: { createdAt: { gte: start, lt: end } },
      select: { status: true },
    }),
    prisma.moderationRecord.findMany({
      where: { createdAt: { gte: start, lt: end } },
      select: { decision: true, createdAt: true },
    }),
  ]);

  return {
    weekKey,
    assessmentCount: assessments.length,
    highRiskCount: assessments.filter((item) => item.riskLevel === 'high').length,
    mediumRiskCount: assessments.filter((item) => item.riskLevel === 'medium').length,
    removedCount: moderationRecords.filter((item) => item.decision === 'remove').length,
    limitedCount: moderationRecords.filter((item) => item.decision === 'limit').length,
    reportCount: reports.length,
    pendingReportCount: reports.filter((item) => item.status === 'pending').length,
    reviewedReportCount: reports.filter((item) => item.status === 'reviewed').length,
    dismissedReportCount: reports.filter((item) => item.status === 'dismissed').length,
    moderationHitRate: assessments.length
      ? Number((assessments.filter((item) => item.decision !== 'approve').length / assessments.length).toFixed(4))
      : 0,
  };
}

function formatWmru(metric) {
  return {
    weekKey: metric.weekKey,
    wmru: metric.wmru,
    payload: metric.payload,
    updatedAt: metric.updatedAt,
  };
}

function currentWeekKey(date = new Date()) {
  const target = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = target.getUTCDay() || 7;
  target.setUTCDate(target.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(target.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((target - yearStart) / 86400000) + 1) / 7);
  return `${target.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

function weekRange(weekKey) {
  const [yearText, weekText] = weekKey.split('-W');
  const year = Number(yearText);
  const week = Number(weekText);
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const jan4Day = jan4.getUTCDay() || 7;
  const start = new Date(jan4);
  start.setUTCDate(jan4.getUTCDate() - jan4Day + 1 + (week - 1) * 7);
  start.setUTCHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setUTCDate(start.getUTCDate() + 7);
  return { start, end };
}

module.exports = {
  ingestEvent,
  calculateWmru,
  getWmru,
  getSafetyMetrics,
  currentWeekKey,
};

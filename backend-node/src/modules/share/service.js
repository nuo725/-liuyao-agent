// Share Module - Business Logic Service

const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const communityService = require('../community/service');

async function renderCard(data) {
  const card = await getSafeCard(data.cardId);
  return {
    imageUrl: buildImageUrl(card.id, data.theme || 'warm'),
    card: formatSafeCard(card),
  };
}

async function saveDraft(userId, data) {
  const prisma = getPrisma();
  const card = await getSafeCard(data.cardId, userId);
  const imageUrl = buildImageUrl(card.id, data.theme || 'warm');
  const draft = await prisma.shareCardDraft.upsert({
    where: { userId_cardId: { userId, cardId: data.cardId } },
    update: {
      theme: data.theme || 'warm',
      text: data.text || '',
      backgroundImageUrl: data.backgroundImageUrl || null,
      imageUrl,
    },
    create: {
      userId,
      cardId: data.cardId,
      theme: data.theme || 'warm',
      text: data.text || '',
      backgroundImageUrl: data.backgroundImageUrl || null,
      imageUrl,
    },
  });

  return {
    draftId: draft.id,
    cardId: draft.cardId,
    imageUrl: draft.imageUrl,
    updatedAt: draft.updatedAt,
  };
}

async function publishToCommunity(userId, data) {
  const post = await communityService.createPost(userId, {
    cardId: data.cardId,
    shareText: data.shareText,
  });
  return {
    postId: post.id,
    status: post.status,
    moderation: post.moderation,
  };
}

async function externalPayload(userId, data) {
  const card = await getSafeCard(data.cardId, userId);
  const safeContent = card.communitySafeContent || {};
  return {
    title: safeContent.summary || '宽窄 Orbit 分享卡',
    summary: safeContent.body || safeContent.summary || '',
    link: `/share/cards/${card.id}?platform=${data.platform || 'generic'}`,
    imageUrl: buildImageUrl(card.id, 'warm'),
  };
}

async function getSafeCard(cardId, userId = null) {
  const prisma = getPrisma();
  const card = await prisma.interpretationCard.findUnique({
    where: { id: cardId },
    include: { session: { select: { userId: true } } },
  });

  if (!card) {
    throw ApiError.notFound('Interpretation card not found');
  }
  if (userId && card.session.userId !== userId) {
    throw ApiError.forbidden('Cannot share another user card');
  }
  const safeContent = card.communitySafeContent;
  if (!safeContent || typeof safeContent !== 'object' || (!safeContent.summary && !safeContent.body)) {
    throw ApiError.badRequest('Card does not have community-safe content');
  }
  return card;
}

function buildImageUrl(cardId, theme) {
  return `/share/cards/${cardId}-${theme}.png`;
}

function formatSafeCard(card) {
  const safeContent = card.communitySafeContent || {};
  return {
    id: card.id,
    summary: safeContent.summary || '',
    body: safeContent.body || '',
    focusPoints: safeContent.focusPoints || [],
    riskLevel: card.riskLevel,
  };
}

module.exports = {
  renderCard,
  saveDraft,
  publishToCommunity,
  externalPayload,
};

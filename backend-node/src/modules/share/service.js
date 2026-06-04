// Share Module - Business Logic Service

const fs = require('fs/promises');
const path = require('path');
const { createHash } = require('crypto');
const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const communityService = require('../community/service');

async function renderCard(data) {
  const card = await getSafeCard(data.cardId);
  const imageUrl = await renderShareCardFile(card, data);
  return {
    imageUrl,
    width: 1200,
    height: 1600,
    format: 'svg',
    card: formatSafeCard(card),
  };
}

async function saveDraft(userId, data) {
  const prisma = getPrisma();
  const card = await getSafeCard(data.cardId, userId);
  const imageUrl = await renderShareCardFile(card, data);
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
  const imageUrl = await renderShareCardFile(card, { theme: 'warm' });
  return {
    title: safeContent.summary || '宽窄 Orbit 分享卡',
    summary: safeContent.body || safeContent.summary || '',
    link: `/share/cards/${card.id}?platform=${data.platform || 'generic'}`,
    imageUrl,
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

async function renderShareCardFile(card, data) {
  const theme = data.theme || 'warm';
  const safeContent = card.communitySafeContent || {};
  const text = data.text || safeContent.body || safeContent.summary || '';
  const hash = createHash('sha1')
    .update(JSON.stringify({ cardId: card.id, theme, text, backgroundImageUrl: data.backgroundImageUrl || '' }))
    .digest('hex')
    .slice(0, 12);
  const filename = `${card.id}-${theme}-${hash}.svg`;
  const outputDir = path.join(__dirname, '..', '..', '..', 'uploads', 'share');
  await fs.mkdir(outputDir, { recursive: true });
  await fs.writeFile(path.join(outputDir, filename), buildShareSvg(card, { ...data, text, theme }), 'utf8');
  return `/uploads/share/${filename}`;
}

function buildShareSvg(card, data) {
  const safeContent = card.communitySafeContent || {};
  const palette = themePalette(data.theme);
  const summary = safeContent.summary || '宽窄 Orbit';
  const body = data.text || safeContent.body || '';
  const focusPoints = Array.isArray(safeContent.focusPoints) ? safeContent.focusPoints : [];
  const bodyLines = wrapText(body, 22).slice(0, 10);
  const focusText = focusPoints.slice(0, 3).join(' · ');

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1600" viewBox="0 0 1200 1600">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="${palette.bg1}"/>
      <stop offset="100%" stop-color="${palette.bg2}"/>
    </linearGradient>
    <filter id="softShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="22" stdDeviation="28" flood-color="#000000" flood-opacity="0.18"/>
    </filter>
  </defs>
  <rect width="1200" height="1600" fill="url(#bg)"/>
  <path d="M0 1190 C180 1110 315 1255 505 1180 C725 1090 860 1015 1200 1105 L1200 1600 L0 1600 Z" fill="${palette.wave}" opacity="0.55"/>
  <circle cx="965" cy="245" r="112" fill="${palette.accent}" opacity="0.16"/>
  <circle cx="195" cy="1310" r="170" fill="${palette.ink}" opacity="0.08"/>
  <rect x="105" y="150" width="990" height="1300" rx="38" fill="${palette.card}" filter="url(#softShadow)" opacity="0.94"/>
  <text x="160" y="245" fill="${palette.muted}" font-size="30" font-family="Noto Sans SC, Microsoft YaHei, Arial">宽窄 Orbit</text>
  <text x="160" y="335" fill="${palette.ink}" font-size="58" font-weight="700" font-family="Noto Sans SC, Microsoft YaHei, Arial">${escapeXml(summary)}</text>
  <line x1="160" y1="405" x2="1040" y2="405" stroke="${palette.line}" stroke-width="2"/>
  ${bodyLines.map((line, index) => `<text x="160" y="${500 + index * 64}" fill="${palette.text}" font-size="40" font-family="Noto Sans SC, Microsoft YaHei, Arial">${escapeXml(line)}</text>`).join('\n  ')}
  <rect x="160" y="1110" width="880" height="132" rx="24" fill="${palette.badge}" opacity="0.9"/>
  <text x="205" y="1188" fill="${palette.ink}" font-size="34" font-family="Noto Sans SC, Microsoft YaHei, Arial">${escapeXml(focusText || '在不确定中整理当下')}</text>
  <text x="160" y="1345" fill="${palette.muted}" font-size="28" font-family="Noto Sans SC, Microsoft YaHei, Arial">不是替你决定，而是帮你看见自己的位置。</text>
  <text x="160" y="1398" fill="${palette.muted}" font-size="24" font-family="Noto Sans SC, Microsoft YaHei, Arial">card: ${escapeXml(card.id)}</text>
</svg>`;
}

function themePalette(theme) {
  const palettes = {
    cool: {
      bg1: '#D9EEF2',
      bg2: '#F7F1E2',
      card: '#FFFDF7',
      ink: '#183B42',
      text: '#284D54',
      muted: '#64777A',
      accent: '#2F8DA0',
      wave: '#B8D9CF',
      line: '#D8E0DC',
      badge: '#E9F5F1',
    },
    dark: {
      bg1: '#1E2524',
      bg2: '#3B3329',
      card: '#F3EFE5',
      ink: '#1F2725',
      text: '#37413D',
      muted: '#756F64',
      accent: '#D3A85C',
      wave: '#756246',
      line: '#D6CCB8',
      badge: '#E7DDC8',
    },
    warm: {
      bg1: '#F4E6D0',
      bg2: '#D7E4D5',
      card: '#FFFDF8',
      ink: '#302A22',
      text: '#50483E',
      muted: '#7B7469',
      accent: '#B66B45',
      wave: '#E7C69C',
      line: '#E7DDCE',
      badge: '#F3E8D5',
    },
  };
  return palettes[theme] || palettes.warm;
}

function wrapText(text, maxChars) {
  const source = String(text || '').replace(/\s+/g, ' ').trim();
  if (!source) return [''];
  const lines = [];
  for (let i = 0; i < source.length; i += maxChars) {
    lines.push(source.slice(i, i + maxChars));
  }
  return lines;
}

function escapeXml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
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

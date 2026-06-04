// Community moderation rules for first-pass text safety.

const { getPrisma } = require('../../db/prisma');

const HIGH_RISK_PATTERNS = [
  { category: 'self_harm', pattern: /(suicide|self[- ]?harm|kill myself|轻生|自杀|自残)/i },
  { category: 'abuse', pattern: /(kill you|die|人肉|网暴|去死|威胁)/i },
  { category: 'porn', pattern: /(porn|nude|裸照|色情|约炮)/i },
  { category: 'spam', pattern: /(spam|loan|rebate|加微|返利|博彩|贷款|刷单|telegram|whatsapp)/i },
];

const PRIVACY_PATTERNS = [
  { category: 'phone', pattern: /(?:\+?86)?1[3-9]\d{9}/ },
  { category: 'email', pattern: /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i },
  { category: 'id_card', pattern: /\b\d{17}[\dXx]\b/ },
];

function assessText(text) {
  const source = String(text || '').trim();
  const categories = [];

  for (const rule of HIGH_RISK_PATTERNS) {
    if (rule.pattern.test(source)) {
      categories.push(rule.category);
    }
  }

  for (const rule of PRIVACY_PATTERNS) {
    if (rule.pattern.test(source)) {
      categories.push(`privacy_${rule.category}`);
    }
  }

  if (categories.some((c) => ['self_harm', 'abuse', 'porn', 'spam'].includes(c))) {
    return {
      decision: 'remove',
      riskLevel: 'high',
      categories,
      reason: 'High-risk or policy-violating content requires manual review before publishing.',
    };
  }

  if (categories.some((c) => c.startsWith('privacy_'))) {
    return {
      decision: 'limit',
      riskLevel: 'medium',
      categories,
      reason: 'Potential private contact or identity information detected.',
    };
  }

  return {
    decision: 'approve',
    riskLevel: 'low',
    categories,
    reason: '',
  };
}

function assessPostPayload({ shareText, card }) {
  const safeCard = card?.communitySafeContent || {};
  const reviewText = [
    shareText,
    safeCard.summary,
    safeCard.body,
    ...(Array.isArray(safeCard.focusPoints) ? safeCard.focusPoints : []),
  ]
    .filter(Boolean)
    .join('\n');

  const result = assessText(reviewText);

  if (card?.riskLevel === 'high' && result.riskLevel !== 'high') {
    return {
      decision: 'limit',
      riskLevel: 'medium',
      categories: [...result.categories, 'card_high_risk'],
      reason: 'Interpretation card is marked high risk and needs moderation before public feed.',
    };
  }

  return result;
}

async function recordAssessment(targetType, targetId, assessment, operator = null) {
  const prisma = getPrisma();
  await prisma.$transaction([
    prisma.safetyAssessment.create({
      data: {
        targetType,
        targetId,
        riskLevel: assessment.riskLevel,
        categories: assessment.categories,
        decision: assessment.decision,
      },
    }),
    prisma.moderationRecord.create({
      data: {
        targetType,
        targetId,
        decision: assessment.decision === 'remove' ? 'remove' : assessment.decision === 'approve' ? 'approve' : 'limit',
        reason: assessment.reason || null,
        operator,
      },
    }),
  ]);
}

module.exports = {
  assessPostPayload,
  assessText,
  recordAssessment,
};

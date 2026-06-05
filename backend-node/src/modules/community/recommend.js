// Recommendation Engine (RECOMMEND-001)
// Provides explainable feed distribution rules for recommended and deep tabs.
// Does NOT use fortune-telling, fate, or personality scoring as signals.

/**
 * Scoring weights for recommended tab.
 * Focus on recency, engagement quality, and content completeness.
 */
const RECOMMENDED_WEIGHTS = {
  recency: 0.35,        // Newer posts score higher
  engagement: 0.25,     // Likes, comments, favorites (quality over quantity)
  contentQuality: 0.20, // Text length, has card, has image
  authorReliability: 0.10, // Author's past engagement ratio
  diversity: 0.10,      // Tag variety to avoid echo chambers
};

/**
 * Scoring weights for deep tab.
 * Focus on content depth, discussion value, and reflection quality.
 */
const DEEP_WEIGHTS = {
  depth: 0.40,          // Longer text, structured content
  discussion: 0.25,     // Comment count and quality
  reflection: 0.20,     // Has feedback, follow-up, multi-day updates
  recency: 0.15,        // Recent but not necessarily brand new
};

/**
 * Score a post for the recommended tab.
 */
function scoreRecommended(post, _viewerContext) {
  const scores = {};

  // Recency: exponential decay over 7 days
  const ageHours = (Date.now() - new Date(post.createdAt).getTime()) / (1000 * 60 * 60);
  scores.recency = Math.exp(-ageHours / 168); // 7-day half-life

  // Engagement: normalized by views (quality ratio)
  const metrics = post.metrics || {};
  const views = metrics.views || 1;
  const engagementActions = (metrics.likes || 0) + (metrics.comments || 0) * 2 + (metrics.favorites || 0) * 1.5;
  scores.engagement = Math.min(engagementActions / views, 1);

  // Content quality: text length, has card, has image
  const textLength = (post.shareText || '').length;
  scores.contentQuality = Math.min(textLength / 200, 1) * 0.5
    + (post.cardId ? 0.3 : 0)
    + (post.coverImageUrl ? 0.2 : 0);

  // Author reliability: placeholder (would use historical engagement ratio)
  scores.authorReliability = 0.5;

  // Diversity: bonus for unique tags
  const tags = post.tabTags || [];
  scores.diversity = Math.min(tags.length / 3, 1);

  // Calculate weighted score
  let totalScore = 0;
  for (const [key, weight] of Object.entries(RECOMMENDED_WEIGHTS)) {
    totalScore += (scores[key] || 0) * weight;
  }

  return {
    score: totalScore,
    breakdown: scores,
    explanation: buildExplanation('recommended', scores),
  };
}

/**
 * Score a post for the deep tab.
 */
function scoreDeep(post) {
  const scores = {};

  // Depth: longer text scores higher
  const textLength = (post.shareText || '').length;
  scores.depth = Math.min(textLength / 500, 1);

  // Discussion: comment count relative to views
  const metrics = post.metrics || {};
  const views = metrics.views || 1;
  scores.discussion = Math.min((metrics.comments || 0) / Math.max(views * 0.1, 1), 1);

  // Reflection: has card, has feedback tags, has follow-up indicators
  const tags = post.tabTags || [];
  scores.reflection = (post.cardId ? 0.4 : 0)
    + (tags.includes('feedback') ? 0.3 : 0)
    + (tags.includes('reflection') ? 0.3 : 0);

  // Recency: slower decay for deep content (30-day half-life)
  const ageHours = (Date.now() - new Date(post.createdAt).getTime()) / (1000 * 60 * 60);
  scores.recency = Math.exp(-ageHours / 720);

  // Calculate weighted score
  let totalScore = 0;
  for (const [key, weight] of Object.entries(DEEP_WEIGHTS)) {
    totalScore += (scores[key] || 0) * weight;
  }

  return {
    score: totalScore,
    breakdown: scores,
    explanation: buildExplanation('deep', scores),
  };
}

/**
 * Apply recommendation scoring to a list of posts.
 */
function rankPosts(posts, tab, viewerContext) {
  const scorer = tab === 'deep' ? scoreDeep : (p) => scoreRecommended(p, viewerContext);

  const scored = posts.map((post) => ({
    post,
    ...scorer(post),
  }));

  // Sort by score descending
  scored.sort((a, b) => b.score - a.score);

  return scored;
}

/**
 * Apply diversity filter to avoid too many posts from same author or tag.
 */
function applyDiversityFilter(rankedPosts, maxPerAuthor = 3, maxPerTag = 5) {
  const authorCounts = {};
  const tagCounts = {};
  const filtered = [];

  for (const item of rankedPosts) {
    const authorId = item.post.authorId;
    const tags = item.post.tabTags || [];

    // Check author limit
    if (authorCounts[authorId] >= maxPerAuthor) continue;

    // Check tag limit (only limit if there are enough posts)
    const tagOverLimit = tags.some((tag) => (tagCounts[tag] || 0) >= maxPerTag);
    if (tagOverLimit && filtered.length > 10) continue;

    // Accept post
    filtered.push(item);
    authorCounts[authorId] = (authorCounts[authorId] || 0) + 1;
    for (const tag of tags) {
      tagCounts[tag] = (tagCounts[tag] || 0) + 1;
    }
  }

  return filtered;
}

/**
 * Build human-readable explanation for why a post was recommended.
 */
function buildExplanation(tab, scores) {
  const reasons = [];

  if (tab === 'recommended') {
    if (scores.recency > 0.8) reasons.push('最近发布');
    if (scores.engagement > 0.5) reasons.push('互动活跃');
    if (scores.contentQuality > 0.6) reasons.push('内容完整');
    if (scores.diversity > 0.5) reasons.push('话题多元');
  } else {
    if (scores.depth > 0.6) reasons.push('内容深入');
    if (scores.discussion > 0.5) reasons.push('讨论热烈');
    if (scores.reflection > 0.5) reasons.push('有反思价值');
  }

  return reasons.length > 0 ? reasons.join('、') : '综合推荐';
}

/**
 * Get recommended posts with scoring and diversity filtering.
 */
async function getRecommendedFeed(prisma, tab, page, pageSize, viewerId) {
  const skip = (page - 1) * pageSize;

  // Fetch more posts than needed for ranking
  const fetchLimit = Math.min(pageSize * 3, 100);

  const where = { status: 'published' };
  if (tab === 'deep') {
    where.OR = [
      { shareText: { gt: 200 } },
      { tabTags: { has: 'reflection' } },
      { tabTags: { has: 'feedback' } },
    ];
  }

  const posts = await prisma.communityPost.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: fetchLimit,
    skip: skip > 0 ? skip : 0,
    include: {
      author: { select: { id: true, username: true, avatarUrl: true } },
    },
  });

  // Rank posts
  const ranked = rankPosts(posts, tab, { viewerId });

  // Apply diversity filter
  const diversified = applyDiversityFilter(ranked);

  // Paginate
  const items = diversified.slice(0, pageSize);

  return {
    items: items.map((item) => ({
      ...item.post,
      _recommendation: {
        score: item.score,
        explanation: item.explanation,
      },
    })),
    hasMore: posts.length >= fetchLimit,
    nextPage: posts.length >= fetchLimit ? page + 1 : null,
  };
}

module.exports = {
  scoreRecommended,
  scoreDeep,
  rankPosts,
  applyDiversityFilter,
  getRecommendedFeed,
};

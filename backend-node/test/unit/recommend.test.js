const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  scoreRecommended,
  scoreDeep,
  rankPosts,
  applyDiversityFilter,
} = require('../../src/modules/community/recommend');

describe('Recommendation engine (RECOMMEND-001)', () => {
  describe('scoreRecommended()', () => {
    it('returns score, breakdown, and explanation', () => {
      const post = {
        createdAt: new Date().toISOString(),
        shareText: 'Test post content',
        metrics: { likes: 5, comments: 2, favorites: 1, views: 100 },
        tabTags: ['career'],
      };
      const result = scoreRecommended(post, {});
      assert.ok(typeof result.score === 'number', 'should have score');
      assert.ok(result.breakdown, 'should have breakdown');
      assert.ok(result.explanation, 'should have explanation');
    });

    it('scores higher for recent posts', () => {
      const recent = { createdAt: new Date().toISOString(), shareText: 'Test', metrics: {}, tabTags: [] };
      const old = { createdAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(), shareText: 'Test', metrics: {}, tabTags: [] };
      const recentScore = scoreRecommended(recent, {});
      const oldScore = scoreRecommended(old, {});
      assert.ok(recentScore.breakdown.recency > oldScore.breakdown.recency, 'recent should score higher');
    });

    it('scores higher for posts with more engagement', () => {
      const popular = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: { likes: 50, comments: 20, favorites: 10, views: 100 },
        tabTags: [],
      };
      const unpopular = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: { likes: 0, comments: 0, favorites: 0, views: 100 },
        tabTags: [],
      };
      const popularScore = scoreRecommended(popular, {});
      const unpopularScore = scoreRecommended(unpopular, {});
      assert.ok(popularScore.breakdown.engagement > unpopularScore.breakdown.engagement);
    });

    it('scores higher for longer text', () => {
      const long = {
        createdAt: new Date().toISOString(),
        shareText: 'A'.repeat(200),
        metrics: {},
        tabTags: [],
      };
      const short = {
        createdAt: new Date().toISOString(),
        shareText: 'Short',
        metrics: {},
        tabTags: [],
      };
      const longScore = scoreRecommended(long, {});
      const shortScore = scoreRecommended(short, {});
      assert.ok(longScore.breakdown.contentQuality > shortScore.breakdown.contentQuality);
    });

    it('gives bonus for having a card', () => {
      const withCard = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        cardId: 'card_1',
        metrics: {},
        tabTags: [],
      };
      const withoutCard = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: {},
        tabTags: [],
      };
      const withScore = scoreRecommended(withCard, {});
      const withoutScore = scoreRecommended(withoutCard, {});
      assert.ok(withScore.breakdown.contentQuality > withoutScore.breakdown.contentQuality);
    });

    it('gives bonus for having an image', () => {
      const withImage = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        coverImageUrl: 'https://example.com/image.jpg',
        metrics: {},
        tabTags: [],
      };
      const withoutImage = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: {},
        tabTags: [],
      };
      const withScore = scoreRecommended(withImage, {});
      const withoutScore = scoreRecommended(withoutImage, {});
      assert.ok(withScore.breakdown.contentQuality > withoutScore.breakdown.contentQuality);
    });

    it('gives bonus for diverse tags', () => {
      const diverse = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: {},
        tabTags: ['career', 'emotion', 'reflection'],
      };
      const single = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: {},
        tabTags: ['career'],
      };
      const diverseScore = scoreRecommended(diverse, {});
      const singleScore = scoreRecommended(single, {});
      assert.ok(diverseScore.breakdown.diversity > singleScore.breakdown.diversity);
    });

    it('explanation contains Chinese reasons', () => {
      const post = {
        createdAt: new Date().toISOString(),
        shareText: 'A'.repeat(200),
        metrics: { likes: 50, comments: 20, favorites: 10, views: 100 },
        tabTags: ['career', 'emotion', 'reflection'],
      };
      const result = scoreRecommended(post, {});
      assert.ok(/[一-鿿]/.test(result.explanation), 'explanation should contain Chinese');
    });
  });

  describe('scoreDeep()', () => {
    it('returns score, breakdown, and explanation', () => {
      const post = {
        createdAt: new Date().toISOString(),
        shareText: 'A'.repeat(500),
        metrics: { comments: 10, views: 100 },
        tabTags: ['reflection'],
        cardId: 'card_1',
      };
      const result = scoreDeep(post);
      assert.ok(typeof result.score === 'number');
      assert.ok(result.breakdown);
      assert.ok(result.explanation);
    });

    it('scores higher for longer text', () => {
      const long = { createdAt: new Date().toISOString(), shareText: 'A'.repeat(500), metrics: {}, tabTags: [] };
      const short = { createdAt: new Date().toISOString(), shareText: 'Short', metrics: {}, tabTags: [] };
      const longScore = scoreDeep(long);
      const shortScore = scoreDeep(short);
      assert.ok(longScore.breakdown.depth > shortScore.breakdown.depth);
    });

    it('scores higher for more comments', () => {
      const commented = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: { comments: 20, views: 100 },
        tabTags: [],
      };
      const noComments = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: { comments: 0, views: 100 },
        tabTags: [],
      };
      const commentedScore = scoreDeep(commented);
      const noCommentsScore = scoreDeep(noComments);
      assert.ok(commentedScore.breakdown.discussion > noCommentsScore.breakdown.discussion);
    });

    it('gives bonus for reflection tags', () => {
      const reflective = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: {},
        tabTags: ['reflection'],
        cardId: 'card_1',
      };
      const plain = {
        createdAt: new Date().toISOString(),
        shareText: 'Test',
        metrics: {},
        tabTags: [],
      };
      const reflectiveScore = scoreDeep(reflective);
      const plainScore = scoreDeep(plain);
      assert.ok(reflectiveScore.breakdown.reflection > plainScore.breakdown.reflection);
    });
  });

  describe('rankPosts()', () => {
    it('sorts posts by score descending', () => {
      const posts = [
        { createdAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(), shareText: 'Old', metrics: {}, tabTags: [] },
        { createdAt: new Date().toISOString(), shareText: 'New', metrics: { likes: 10, views: 50 }, tabTags: ['career'] },
      ];
      const ranked = rankPosts(posts, 'recommended', {});
      assert.ok(ranked[0].score >= ranked[1].score, 'should sort by score descending');
    });

    it('returns all posts', () => {
      const posts = [
        { createdAt: new Date().toISOString(), shareText: 'A', metrics: {}, tabTags: [] },
        { createdAt: new Date().toISOString(), shareText: 'B', metrics: {}, tabTags: [] },
        { createdAt: new Date().toISOString(), shareText: 'C', metrics: {}, tabTags: [] },
      ];
      const ranked = rankPosts(posts, 'recommended', {});
      assert.equal(ranked.length, 3);
    });

    it('uses deep scorer for deep tab', () => {
      const posts = [
        { createdAt: new Date().toISOString(), shareText: 'A'.repeat(500), metrics: { comments: 10, views: 50 }, tabTags: ['reflection'], cardId: 'card_1' },
      ];
      const ranked = rankPosts(posts, 'deep', {});
      assert.ok(ranked[0].breakdown.depth !== undefined, 'deep scorer should have depth');
    });
  });

  describe('applyDiversityFilter()', () => {
    it('limits posts per author', () => {
      const ranked = Array.from({ length: 10 }, (_, i) => ({
        post: { authorId: 'user_1', tabTags: [`tag_${i}`] },
        score: 1 - i * 0.1,
      }));
      const filtered = applyDiversityFilter(ranked, 3, 100);
      const user1Count = filtered.filter((item) => item.post.authorId === 'user_1').length;
      assert.ok(user1Count <= 3, `should limit to 3 per author, got ${user1Count}`);
    });

    it('limits posts per tag', () => {
      const ranked = Array.from({ length: 20 }, (_, i) => ({
        post: { authorId: `user_${i}`, tabTags: ['common_tag'] },
        score: 1 - i * 0.05,
      }));
      const filtered = applyDiversityFilter(ranked, 100, 5);
      // After 10 posts, tag limit kicks in
      assert.ok(filtered.length < 20, 'should filter some posts');
    });

    it('returns all posts when within limits', () => {
      const ranked = [
        { post: { authorId: 'user_1', tabTags: ['tag_1'] }, score: 0.9 },
        { post: { authorId: 'user_2', tabTags: ['tag_2'] }, score: 0.8 },
      ];
      const filtered = applyDiversityFilter(ranked, 3, 5);
      assert.equal(filtered.length, 2);
    });

    it('preserves score order', () => {
      const ranked = [
        { post: { authorId: 'user_1', tabTags: ['tag_1'] }, score: 0.9 },
        { post: { authorId: 'user_2', tabTags: ['tag_2'] }, score: 0.8 },
        { post: { authorId: 'user_3', tabTags: ['tag_3'] }, score: 0.7 },
      ];
      const filtered = applyDiversityFilter(ranked, 10, 10);
      assert.ok(filtered[0].score >= filtered[1].score);
      assert.ok(filtered[1].score >= filtered[2].score);
    });
  });
});

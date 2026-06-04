// Community Module Routes (COMMUNITY-001 ~ COMMUNITY-012)
// Feed, posts, comments, likes, favorites, reports, follow, block, search

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth, optionalAuth } = require('../../middleware/auth');
const { idempotency } = require('../../middleware/idempotency');
const communityService = require('./service');
const schemas = require('./schema');

const router = Router();

// GET /feed - List feed by tab
router.get('/feed', optionalAuth, validate(schemas.feedSchema, 'query'), async (req, res, next) => {
  try {
    const { tab, page, pageSize } = req.validated.query;
    const result = await communityService.getFeed(tab, page, pageSize, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /post/:id - Post detail
router.get('/post/:id', optionalAuth, async (req, res, next) => {
  try {
    const result = await communityService.getPostDetail(req.params.id, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /post/:id/comments - Comment thread
router.get('/post/:id/comments', validate(schemas.paginationSchema, 'query'), async (req, res, next) => {
  try {
    const { page, pageSize } = req.validated.query;
    const result = await communityService.getComments(req.params.id, page, pageSize);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /post/:id/comments - Add comment
router.post('/post/:id/comments', requireAuth, idempotency, validate(schemas.createCommentSchema), async (req, res, next) => {
  try {
    const { text, parentId } = req.validated.body;
    const result = await communityService.createComment(req.params.id, req.userId, text, parentId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /post - Publish a post
router.post('/post', requireAuth, idempotency, validate(schemas.createPostSchema), async (req, res, next) => {
  try {
    const result = await communityService.createPost(req.userId, req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /post/:id/like - Like post
router.post('/post/:id/like', requireAuth, async (req, res, next) => {
  try {
    const result = await communityService.likePost(req.params.id, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /post/:id/unlike - Unlike post
router.post('/post/:id/unlike', requireAuth, async (req, res, next) => {
  try {
    const result = await communityService.unlikePost(req.params.id, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /post/:id/favorite - Favorite post
router.post('/post/:id/favorite', requireAuth, async (req, res, next) => {
  try {
    const result = await communityService.favoritePost(req.params.id, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /post/:id/unfavorite - Unfavorite post
router.post('/post/:id/unfavorite', requireAuth, async (req, res, next) => {
  try {
    const result = await communityService.unfavoritePost(req.params.id, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /post/:id/report - Report post
router.post('/post/:id/report', requireAuth, validate(schemas.reportSchema), async (req, res, next) => {
  try {
    const { reason, detail } = req.validated.body;
    const result = await communityService.reportPost(req.params.id, req.userId, reason, detail);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /post/:id/hide - Hide post
router.post('/post/:id/hide', requireAuth, async (req, res, next) => {
  try {
    const result = await communityService.hidePost(req.params.id, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /author/:authorId - Author profile
router.get('/author/:authorId', optionalAuth, async (req, res, next) => {
  try {
    const result = await communityService.getAuthorProfile(req.params.authorId, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /author/:authorId/follow - Follow author
router.post('/author/:authorId/follow', requireAuth, async (req, res, next) => {
  try {
    const result = await communityService.followAuthor(req.userId, req.params.authorId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /author/:authorId/unfollow - Unfollow author
router.post('/author/:authorId/unfollow', requireAuth, async (req, res, next) => {
  try {
    const result = await communityService.unfollowAuthor(req.userId, req.params.authorId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /author/:authorId/block - Block user
router.post('/author/:authorId/block', requireAuth, async (req, res, next) => {
  try {
    const result = await communityService.blockUser(req.userId, req.params.authorId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /author/:authorId/unblock - Unblock user
router.post('/author/:authorId/unblock', requireAuth, async (req, res, next) => {
  try {
    const result = await communityService.unblockUser(req.userId, req.params.authorId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /search - Unified search
router.get('/search', validate(schemas.searchSchema, 'query'), async (req, res, next) => {
  try {
    const { q, type, page, pageSize } = req.validated.query;
    const result = await communityService.search(q, type, page, pageSize);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /feed/by-tag - Tag-based feed
router.get('/feed/by-tag', validate(schemas.tagFeedSchema, 'query'), async (req, res, next) => {
  try {
    res.json(ok({ message: 'Not implemented' }));
  } catch (err) {
    next(err);
  }
});

// POST /tags/subscribe - Subscribe to tag
router.post('/tags/subscribe', requireAuth, validate(schemas.subscribeTagSchema), async (req, res, next) => {
  try {
    res.json(ok({ message: 'Not implemented' }));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

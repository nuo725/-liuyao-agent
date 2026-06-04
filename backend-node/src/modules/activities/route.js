// Activities Module Routes (ACTIVITY-001 ~ ACTIVITY-004)
// Endpoints: list, detail, join, join-status, submit, leaderboard, tag-distribution

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth, optionalAuth, requireRole } = require('../../middleware/auth');
const { idempotency } = require('../../middleware/idempotency');
const activityService = require('./service');
const schemas = require('./schema');

const router = Router();

// POST /admin - Create activity
router.post('/admin', requireAuth, requireRole(['operator', 'admin']), validate(schemas.activityBodySchema), async (req, res, next) => {
  try {
    const result = await activityService.createActivity(req.validated.body, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// PUT /admin/:id - Update activity
router.put('/admin/:id', requireAuth, requireRole(['operator', 'admin']), validate(schemas.updateActivitySchema), async (req, res, next) => {
  try {
    const result = await activityService.updateActivity(req.params.id, req.validated.body, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /list - List activities
router.get('/list', optionalAuth, validate(schemas.listSchema, 'query'), async (req, res, next) => {
  try {
    const { page, pageSize } = req.validated.query;
    const result = await activityService.listActivities(page, pageSize, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /:id - Activity detail
router.get('/:id', optionalAuth, async (req, res, next) => {
  try {
    const result = await activityService.getActivityDetail(req.params.id, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /:id/join - Join activity
router.post('/:id/join', requireAuth, idempotency, async (req, res, next) => {
  try {
    const result = await activityService.joinActivity(req.params.id, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /:id/join-status - Get join status
router.get('/:id/join-status', requireAuth, async (req, res, next) => {
  try {
    const result = await activityService.getJoinStatus(req.params.id, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /:id/submit - Submit post to campaign
router.post('/:id/submit', (req, res) => {
  res.json(ok({ message: 'Not implemented' }));
});

// GET /:id/leaderboard - Campaign leaderboard
router.get('/:id/leaderboard', (req, res) => {
  res.json(ok({ message: 'Not implemented' }));
});

// GET /:id/tag-distribution - Tag distribution
router.get('/:id/tag-distribution', (req, res) => {
  res.json(ok({ message: 'Not implemented' }));
});

module.exports = router;

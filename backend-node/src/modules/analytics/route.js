// Analytics Module Routes (ANALYTICS-001 ~ ANALYTICS-003)

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth, requireRole } = require('../../middleware/auth');
const analyticsService = require('./service');
const schemas = require('./schema');

const router = Router();

router.post('/events', requireAuth, validate(schemas.eventSchema), async (req, res, next) => {
  try {
    const result = await analyticsService.ingestEvent(req.userId, req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

router.get('/wmru', requireAuth, requireRole(['operator', 'admin']), validate(schemas.metricQuerySchema, 'query'), async (req, res, next) => {
  try {
    const result = await analyticsService.getWmru(req.validated.query.weekKey);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

router.post('/wmru/recalculate', requireAuth, requireRole(['operator', 'admin']), validate(schemas.metricQuerySchema), async (req, res, next) => {
  try {
    const result = await analyticsService.calculateWmru(req.validated.body.weekKey);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

router.get('/safety', requireAuth, requireRole(['operator', 'admin']), validate(schemas.metricQuerySchema, 'query'), async (req, res, next) => {
  try {
    const result = await analyticsService.getSafetyMetrics(req.validated.query.weekKey);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

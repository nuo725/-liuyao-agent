// Match Module Routes (MATCH-001 ~ MATCH-003)
// Endpoints: unlock, same-frequency, radar/status

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth } = require('../../middleware/auth');
const { idempotency } = require('../../middleware/idempotency');
const { requireFeature } = require('../../shared/feature-flags');
const matchService = require('./service');
const schemas = require('./schema');

const router = Router();

// POST /unlock - Unlock same-frequency feature
router.post('/unlock', requireFeature('match_enabled'), requireAuth, idempotency, validate(schemas.unlockSchema), async (req, res, next) => {
  try {
    const result = await matchService.unlock(req.userId, req.validated.body.deviceId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /same-frequency - Get same-frequency users/history
router.get('/same-frequency', requireAuth, validate(schemas.sameFrequencySchema, 'query'), async (req, res, next) => {
  try {
    const { tab, page, pageSize } = req.validated.query;
    const result = await matchService.getSameFrequency(req.userId, tab, page, pageSize);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /radar/status - Get unlock state + today's signature
router.get('/radar/status', requireAuth, async (req, res, next) => {
  try {
    const result = await matchService.getRadarStatus(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

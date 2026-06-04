// Share Module Routes (SHARE-001 ~ SHARE-004)
// Endpoints: card/render, card/save, community/publish, external

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth } = require('../../middleware/auth');
const { idempotency } = require('../../middleware/idempotency');
const shareService = require('./service');
const schemas = require('./schema');

const router = Router();

// POST /card/render - Generate card image
router.post('/card/render', validate(schemas.renderSchema), async (req, res, next) => {
  try {
    const result = await shareService.renderCard(req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /card/save - Save card draft
router.post('/card/save', requireAuth, idempotency, validate(schemas.saveSchema), async (req, res, next) => {
  try {
    const result = await shareService.saveDraft(req.userId, req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /community/publish - Publish card to community
router.post('/community/publish', requireAuth, idempotency, validate(schemas.publishSchema), async (req, res, next) => {
  try {
    const result = await shareService.publishToCommunity(req.userId, req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /external - Trigger external share
router.post('/external', requireAuth, validate(schemas.externalSchema), async (req, res, next) => {
  try {
    const result = await shareService.externalPayload(req.userId, req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

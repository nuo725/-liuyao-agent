// Support Module Routes (SUPPORT-001)
// Endpoints: feedback

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth } = require('../../middleware/auth');
const supportService = require('./service');
const schemas = require('./schema');

const router = Router();

// POST /feedback - Submit feedback ticket
router.post('/feedback', requireAuth, validate(schemas.feedbackSchema), async (req, res, next) => {
  try {
    const result = await supportService.submitFeedback(req.userId, req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

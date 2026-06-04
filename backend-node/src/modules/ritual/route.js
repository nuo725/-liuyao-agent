// Ritual Module Routes (RITUAL-001 ~ RITUAL-009)
// Ritual sessions, interpretation, follow-up, SSE streaming

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth, optionalAuth } = require('../../middleware/auth');
const { idempotency } = require('../../middleware/idempotency');
const ritualService = require('./service');
const schemas = require('./schema');

const router = Router();

// POST /perform - Create ritual session
router.post('/perform', optionalAuth, idempotency, validate(schemas.performSchema), async (req, res, next) => {
  try {
    const { question, tag, lines, movingLines } = req.validated.body;
    const result = await ritualService.perform(req.userId, question, tag, lines, movingLines, req.headers['idempotency-key']);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId - Restore session
router.get('/session/:sessionId', requireAuth, async (req, res, next) => {
  try {
    const result = await ritualService.getSession(req.params.sessionId, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId/preview - First-ritual preview (no auth)
router.get('/session/:sessionId/preview', async (req, res, next) => {
  try {
    const result = await ritualService.getPreview(req.params.sessionId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId/full-read - Full interpretation
router.get('/session/:sessionId/full-read', requireAuth, async (req, res, next) => {
  try {
    const result = await ritualService.getFullInterpretation(req.params.sessionId, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /session/:sessionId/continue - Follow-up message
router.post('/session/:sessionId/continue', requireAuth, idempotency, validate(schemas.continueSchema), async (req, res, next) => {
  try {
    const result = await ritualService.addFollowup(req.params.sessionId, req.userId, req.validated.body.message, req.headers['idempotency-key']);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId/chat-history - Chat message history
router.get('/session/:sessionId/chat-history', requireAuth, async (req, res, next) => {
  try {
    const result = await ritualService.getChatHistory(req.params.sessionId, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /session/:sessionId/chat - Continue conversation (SSE)
router.post('/session/:sessionId/chat', requireAuth, async (req, res, next) => {
  try {
    // TODO: Implement SSE streaming
    res.json(ok({ message: 'SSE streaming not yet implemented' }));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId/interpretation/stream - SSE stream
router.get('/session/:sessionId/interpretation/stream', requireAuth, async (req, res, next) => {
  try {
    // TODO: Implement SSE streaming
    res.json(ok({ message: 'SSE streaming not yet implemented' }));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId/followup/stream - SSE follow-up stream
router.get('/session/:sessionId/followup/stream', requireAuth, async (req, res, next) => {
  try {
    // TODO: Implement SSE streaming
    res.json(ok({ message: 'SSE streaming not yet implemented' }));
  } catch (err) {
    next(err);
  }
});

// GET /user/:userId/completion-today - Daily completion status
router.get('/user/:userId/completion-today', requireAuth, async (req, res, next) => {
  try {
    if (req.params.userId !== req.userId) {
      const { ApiError } = require('../../shared/api-error');
      throw ApiError.forbidden('Cannot read another user completion status');
    }
    const result = await ritualService.getCompletionToday(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /session/:sessionId/calibration - Save emotional calibration feedback
router.post('/session/:sessionId/calibration', requireAuth, validate(schemas.calibrationSchema), async (req, res, next) => {
  try {
    const result = await ritualService.saveEmotionCalibration(req.params.sessionId, req.userId, req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /me/periodic-review - Periodic reflection review
router.get('/me/periodic-review', requireAuth, validate(schemas.reviewQuerySchema, 'query'), async (req, res, next) => {
  try {
    const result = await ritualService.getPeriodicReview(req.userId, req.validated.query.days);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId/tag-profile - Tag identity snapshot
router.get('/session/:sessionId/tag-profile', requireAuth, async (req, res, next) => {
  try {
    res.json(ok({ message: 'Not implemented' }));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId/tag-timeline - Chronological tag timeline
router.get('/session/:sessionId/tag-timeline', requireAuth, validate(schemas.paginationSchema, 'query'), async (req, res, next) => {
  try {
    res.json(ok({ message: 'Not implemented' }));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId/tag-explanation - Human-readable tag explanation
router.get('/session/:sessionId/tag-explanation', requireAuth, async (req, res, next) => {
  try {
    res.json(ok({ message: 'Not implemented' }));
  } catch (err) {
    next(err);
  }
});

// ─────── Feedback (Phase 9) ───────

const feedbackService = require('./feedback-service');

// POST /session/:sessionId/feedback - Submit feedback
router.post('/session/:sessionId/feedback', requireAuth, async (req, res, next) => {
  try {
    const result = await feedbackService.submitFeedback(req.userId, req.params.sessionId, req.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /session/:sessionId/feedback - Get session feedback
router.get('/session/:sessionId/feedback', requireAuth, async (req, res, next) => {
  try {
    const result = await feedbackService.getSessionFeedback(req.params.sessionId, req.userId);
    res.json(ok({ items: result }));
  } catch (err) {
    next(err);
  }
});

// GET /me/feedback - Get feedback history
router.get('/me/feedback', requireAuth, validate(schemas.paginationSchema, 'query'), async (req, res, next) => {
  try {
    const { page, pageSize } = req.validated.query;
    const result = await feedbackService.getFeedbackHistory(req.userId, page, pageSize);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /feedback/:feedbackId/publish - Publish feedback to community
router.post('/feedback/:feedbackId/publish', requireAuth, async (req, res, next) => {
  try {
    const result = await feedbackService.createFeedbackPost(req.userId, req.params.feedbackId, req.body.shareText);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

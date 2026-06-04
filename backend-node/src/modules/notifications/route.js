// Notifications Module Routes (NOTIFY-001 ~ NOTIFY-006)
// Endpoints: list, unread-count, read, read-all, dismiss, token, state

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth } = require('../../middleware/auth');
const notificationService = require('./service');
const schemas = require('./schema');

const router = Router();

router.use(requireAuth);

// GET / - List notifications
router.get('/', validate(schemas.listSchema, 'query'), async (req, res, next) => {
  try {
    const { type, page, pageSize } = req.validated.query;
    const result = await notificationService.listNotifications(req.userId, type, page, pageSize);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /unread-count - Get unread count
router.get('/unread-count', async (req, res, next) => {
  try {
    const result = await notificationService.getUnreadCount(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /:id/read - Mark single read
router.post('/:id/read', async (req, res, next) => {
  try {
    const result = await notificationService.markRead(req.userId, req.params.id);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /read-all - Mark all read
router.post('/read-all', async (req, res, next) => {
  try {
    const result = await notificationService.markAllRead(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /:id/dismiss - Dismiss notification
router.post('/:id/dismiss', async (req, res, next) => {
  try {
    const result = await notificationService.dismiss(req.userId, req.params.id);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /token - Register push token
router.post('/token', validate(schemas.tokenSchema), async (req, res, next) => {
  try {
    const { token, platform } = req.validated.body;
    const result = await notificationService.registerToken(req.userId, token, platform);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// DELETE /token - Unregister push token
router.delete('/token', validate(schemas.unregisterTokenSchema), async (req, res, next) => {
  try {
    const result = await notificationService.unregisterToken(req.userId, req.validated.body.token);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// PUT /state - Batch sync read/dismissed state
router.put('/state', validate(schemas.stateSchema), async (req, res, next) => {
  try {
    const { readIds, dismissedIds } = req.validated.body;
    const result = await notificationService.syncState(req.userId, readIds, dismissedIds);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

// Media Module Routes (PROFILE-002)
// Endpoints: upload

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { requireAuth } = require('../../middleware/auth');
const mediaService = require('./service');

const router = Router();

// POST /upload - Upload media file
router.post('/upload', requireAuth, async (req, res, next) => {
  try {
    const result = await mediaService.uploadMedia(req.userId, req);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

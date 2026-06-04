// Profile Module Routes (PROFILE-001 ~ PROFILE-007)
// Personal profile, settings, checkin, interactions, account deletion

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth, optionalAuth } = require('../../middleware/auth');
const profileService = require('./service');
const schemas = require('./schema');

const router = Router();

// GET /public/:shortId - Public profile page
router.get('/public/:shortId', optionalAuth, async (req, res, next) => {
  try {
    const result = await profileService.getPublicProfile(req.params.shortId, req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// All profile routes require auth
router.use(requireAuth);

// GET /me - Get own profile
router.get('/me', async (req, res, next) => {
  try {
    const result = await profileService.getMyProfile(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// PUT /me - Update profile
router.put('/me', validate(schemas.updateProfileSchema), async (req, res, next) => {
  try {
    const result = await profileService.updateMyProfile(req.userId, req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// DELETE /me - Account deletion
router.delete('/me', validate(schemas.deleteAccountSchema), async (req, res, next) => {
  try {
    const result = await profileService.requestDeleteAccount(req.userId, req.validated.body.confirmText);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /me/settings - Get settings
router.get('/me/settings', async (req, res, next) => {
  try {
    const result = await profileService.getMySettings(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// PUT /me/settings - Update settings
router.put('/me/settings', validate(schemas.updateSettingsSchema), async (req, res, next) => {
  try {
    const result = await profileService.updateMySettings(req.userId, req.validated.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /me/checkin-calendar - Get monthly check-in calendar
router.get('/me/checkin-calendar', validate(schemas.checkinCalendarSchema, 'query'), async (req, res, next) => {
  try {
    const month = req.validated.query?.month;
    const result = await profileService.getCheckinCalendar(req.userId, month);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /me/checkin - Daily check-in
router.post('/me/checkin', async (req, res, next) => {
  try {
    const result = await profileService.checkin(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /me/interactions - Interaction timeline
router.get('/me/interactions', validate(schemas.paginationSchema, 'query'), async (req, res, next) => {
  try {
    const { page, pageSize } = req.validated.query;
    const result = await profileService.getInteractions(req.userId, page, pageSize);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /me/browse - Browse history
router.get('/me/browse', validate(schemas.paginationSchema, 'query'), async (req, res, next) => {
  try {
    const { page, pageSize } = req.validated.query;
    const result = await profileService.getBrowseHistory(req.userId, page, pageSize);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /me/avatar - Use an uploaded media asset as avatar
router.post('/me/avatar', validate(schemas.mediaRefSchema), async (req, res, next) => {
  try {
    const result = await profileService.updateAvatar(req.userId, req.validated.body.mediaId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /me/cover - Use an uploaded media asset as cover
router.post('/me/cover', validate(schemas.mediaRefSchema), async (req, res, next) => {
  try {
    const result = await profileService.updateCover(req.userId, req.validated.body.mediaId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /me/share-card - Get share URL
router.get('/me/share-card', async (req, res, next) => {
  try {
    const result = await profileService.getShareCard(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// ─────── Anonymous Identity (Phase 9) ───────

const anonymousService = require('./anonymous-service');

// GET /me/anonymous - Get or create anonymous profile
router.get('/me/anonymous', async (req, res, next) => {
  try {
    const result = await anonymousService.getOrCreateProfile(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// PUT /me/anonymous - Update anonymous profile
router.put('/me/anonymous', async (req, res, next) => {
  try {
    const result = await anonymousService.updateProfile(req.userId, req.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /me/anonymous/post - Create anonymous post
router.post('/me/anonymous/post', async (req, res, next) => {
  try {
    const result = await anonymousService.createAnonymousPost(req.userId, req.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

// Auth Module Routes (AUTH-001 ~ AUTH-005)
// Phone verification, login, token management, guest upgrade

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth } = require('../../middleware/auth');
const { rateLimit } = require('../../middleware/rate-limit');
const { idempotency } = require('../../middleware/idempotency');
const authService = require('./service');
const schemas = require('./schema');

const router = Router();

// POST /phone/send-code - Send SMS verification code
router.post(
  '/phone/send-code',
  rateLimit('send-code', 5, 60), // 5 per minute
  validate(schemas.sendCodeSchema),
  async (req, res, next) => {
    try {
      const result = await authService.sendVerificationCode(req.validated.body.phone);
      res.json(ok(result));
    } catch (err) {
      next(err);
    }
  }
);

// POST /phone/login - Phone + code login
router.post(
  '/phone/login',
  rateLimit('phone-login', 10, 60),
  idempotency,
  validate(schemas.phoneLoginSchema),
  async (req, res, next) => {
    try {
      const { phone, code, agreementVersion, privacyVersion, consentedAt } = req.validated.body;
      const result = await authService.phoneLogin(phone, code, {
        agreementVersion,
        privacyVersion,
        consentedAt,
      });
      res.json(ok(result));
    } catch (err) {
      next(err);
    }
  }
);

// POST /social/login - WeChat/QQ social login
router.post(
  '/social/login',
  validate(schemas.socialLoginSchema),
  async (req, res, next) => {
    try {
      const { provider, authCode, agreementVersion, privacyVersion, consentedAt } = req.validated.body;
      const result = await authService.socialLogin(provider, authCode, {
        agreementVersion,
        privacyVersion,
        consentedAt,
      });
      res.json(ok(result));
    } catch (err) {
      next(err);
    }
  }
);

// POST /password/recovery - Password recovery
router.post(
  '/password/recovery',
  rateLimit('password-recovery', 3, 300), // 3 per 5 min
  validate(schemas.passwordRecoverySchema),
  async (req, res, next) => {
    try {
      // TODO: Implement password recovery
      res.json(ok({ message: 'Not implemented' }));
    } catch (err) {
      next(err);
    }
  }
);

// GET /session - Restore session from token
router.get('/session', requireAuth, async (req, res, next) => {
  try {
    const result = await authService.restoreSession(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /refresh - Refresh access token
router.post(
  '/refresh',
  validate(schemas.refreshTokenSchema),
  async (req, res, next) => {
    try {
      const result = await authService.refreshSession(req.validated.body.refreshToken);
      res.json(ok(result));
    } catch (err) {
      next(err);
    }
  }
);

// POST /logout - Logout
router.post('/logout', requireAuth, async (req, res, next) => {
  try {
    const refreshToken = req.body?.refreshToken;
    const result = await authService.logout(req.userId, refreshToken);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /guest/upgrade - Upgrade guest to registered account
router.post(
  '/guest/upgrade',
  requireAuth,
  validate(schemas.guestUpgradeSchema),
  async (req, res, next) => {
    try {
      const { phone, code } = req.validated.body;
      const result = await authService.upgradeGuest(req.userId, phone, code);
      res.json(ok(result));
    } catch (err) {
      next(err);
    }
  }
);

module.exports = router;

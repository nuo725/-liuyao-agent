// Credits Module Routes (CREDIT-001 ~ CREDIT-003)
// Credit account, consume, daily reset

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth } = require('../../middleware/auth');
const { idempotency } = require('../../middleware/idempotency');
const creditService = require('./service');
const { consumeSchema } = require('./schema');

const router = Router();

router.use(requireAuth);

// GET /account - Get credit account balances
router.get('/account', async (req, res, next) => {
  try {
    const result = await creditService.getAccount(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /consume - Consume a credit
router.post('/consume', idempotency, validate(consumeSchema), async (req, res, next) => {
  try {
    const { type, amount } = req.validated.body;
    const idempotencyKey = req.headers['idempotency-key'];
    const result = await creditService.consume(req.userId, type, amount, idempotencyKey);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /reset - Server-side daily reset
router.post('/reset', async (req, res, next) => {
  try {
    const result = await creditService.resetDaily(req.userId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

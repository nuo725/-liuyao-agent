// Billing Module Routes (BILLING-001 ~ BILLING-004)
// Endpoints: plans, order/create, order/confirm, order/:orderId

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { validate } = require('../../middleware/validate');
const { requireAuth } = require('../../middleware/auth');
const { idempotency } = require('../../middleware/idempotency');
const billingService = require('./service');
const schemas = require('./schema');

const router = Router();

router.use(requireAuth);

// GET /plans - List available VIP plans
router.get('/plans', async (req, res, next) => {
  try {
    const result = await billingService.listPlans();
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /order/create - Create purchase order
router.post('/order/create', idempotency, validate(schemas.createOrderSchema), async (req, res, next) => {
  try {
    const result = await billingService.createOrder(req.userId, req.validated.body.planId, req.headers['idempotency-key']);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// POST /order/confirm - Confirm payment
router.post('/order/confirm', validate(schemas.confirmOrderSchema), async (req, res, next) => {
  try {
    const { orderId, providerOrderId, signature } = req.validated.body;
    const result = await billingService.confirmPayment(req.userId, orderId, providerOrderId, signature);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

// GET /order/:orderId - Get order status
router.get('/order/:orderId', async (req, res, next) => {
  try {
    const result = await billingService.getOrder(req.userId, req.params.orderId);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

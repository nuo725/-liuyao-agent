// Billing Module - Zod Validation Schemas

const { z } = require('zod');

const createOrderSchema = z.object({
  planId: z.string().min(1),
});

const confirmOrderSchema = z.object({
  orderId: z.string().min(1),
  providerOrderId: z.string().min(1).optional(),
  signature: z.string().optional(),
});

module.exports = {
  createOrderSchema,
  confirmOrderSchema,
};

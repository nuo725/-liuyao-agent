// Analytics Module - Zod Validation Schemas

const { z } = require('zod');

const eventSchema = z.object({
  eventName: z.string().min(1).max(80),
  payload: z.record(z.unknown()).default({}),
  client: z.record(z.unknown()).optional(),
  occurredAt: z.string().datetime().optional(),
});

const metricQuerySchema = z.object({
  weekKey: z.string().regex(/^\d{4}-W\d{2}$/).optional(),
});

module.exports = {
  eventSchema,
  metricQuerySchema,
};

// Credits Module - Zod Validation Schemas

const { z } = require('zod');

const consumeSchema = z.object({
  type: z.enum(['cast', 'followup']),
  amount: z.coerce.number().int().min(1).default(1),
  sessionId: z.string().optional(),
});

module.exports = { consumeSchema };

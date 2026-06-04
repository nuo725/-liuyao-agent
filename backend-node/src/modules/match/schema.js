// Match Module - Zod Validation Schemas

const { z } = require('zod');

const unlockSchema = z.object({
  deviceId: z.string().min(1).max(100).optional(),
  trigger: z.enum(['shake']).default('shake'),
});

const sameFrequencySchema = z.object({
  tab: z.enum(['users', 'history']).default('users'),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

module.exports = {
  unlockSchema,
  sameFrequencySchema,
};

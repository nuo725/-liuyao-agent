// Notifications Module - Zod Validation Schemas

const { z } = require('zod');

const listSchema = z.object({
  type: z.enum(['all', 'system', 'interaction', 'activity', 'agent']).default('all'),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

const tokenSchema = z.object({
  token: z.string().min(1).max(500),
  platform: z.enum(['android', 'ios', 'web']),
});

const unregisterTokenSchema = z.object({
  token: z.string().min(1).max(500).optional(),
});

const stateSchema = z.object({
  readIds: z.array(z.string()).default([]),
  dismissedIds: z.array(z.string()).default([]),
});

module.exports = {
  listSchema,
  tokenSchema,
  unregisterTokenSchema,
  stateSchema,
};

// Activities Module - Zod Validation Schemas

const { z } = require('zod');

const listSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

const activityBodySchema = z.object({
  title: z.string().min(1).max(80),
  description: z.string().max(2000).default(''),
  imageUrl: z.string().url().optional(),
  status: z.enum(['registering', 'ongoing', 'ended']).default('registering'),
  startAt: z.string().datetime().optional(),
  endAt: z.string().datetime().optional(),
  capacity: z.coerce.number().int().min(1).optional(),
});

const updateActivitySchema = activityBodySchema.partial();

module.exports = {
  listSchema,
  activityBodySchema,
  updateActivitySchema,
};

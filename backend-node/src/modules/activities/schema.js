// Activities Module - Zod Validation Schemas

const { z } = require('zod');

const listSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

module.exports = {
  listSchema,
};

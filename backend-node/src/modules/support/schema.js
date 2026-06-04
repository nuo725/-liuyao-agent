// Support Module - Zod Validation Schemas

const { z } = require('zod');

const feedbackSchema = z.object({
  category: z.enum(['bug', 'suggestion', 'abuse', 'other']),
  content: z.string().min(1).max(2000),
  contact: z.string().max(200).optional(),
  client: z.object({
    platform: z.enum(['android', 'ios', 'web']).optional(),
    version: z.string().max(50).optional(),
  }).optional(),
});

module.exports = {
  feedbackSchema,
};

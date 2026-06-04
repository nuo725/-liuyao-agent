// Ritual Module - Zod Validation Schemas

const { z } = require('zod');

const performSchema = z.object({
  question: z.string().min(1, 'Question required').max(500),
  tag: z.enum(['relationship', 'career', 'emotion', 'choice', 'other']),
  lines: z.array(z.enum([0, 1])).length(6, 'Must have exactly 6 lines'),
  movingLines: z.array(z.number().int().min(0).max(5)).default([]),
});

const continueSchema = z.object({
  message: z.string().min(1).max(500),
});

const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

const calibrationSchema = z.object({
  feedback: z.enum(['resonated', 'neutral', 'not_resonated']).optional(),
  customText: z.string().max(500).optional(),
}).refine((data) => data.feedback || data.customText, {
  message: 'feedback or customText required',
  path: ['feedback'],
});

const reviewQuerySchema = z.object({
  days: z.coerce.number().int().min(7).max(365).default(30),
});

module.exports = {
  performSchema,
  continueSchema,
  paginationSchema,
  calibrationSchema,
  reviewQuerySchema,
};

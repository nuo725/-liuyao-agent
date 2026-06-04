// Community Module - Zod Validation Schemas

const { z } = require('zod');

const feedSchema = z.object({
  tab: z.enum(['recommended', 'deep']).default('recommended'),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

const createPostSchema = z.object({
  cardId: z.string().optional(),
  shareText: z.string().min(1).max(2000),
  coverImageUrl: z.string().url().optional(),
});

const createCommentSchema = z.object({
  text: z.string().min(1).max(500),
  parentId: z.string().optional(),
});

const reportSchema = z.object({
  reason: z.enum(['porn', 'spam', 'abuse', 'other']),
  detail: z.string().max(500).optional(),
});

const searchSchema = z.object({
  q: z.string().min(1),
  type: z.enum(['all', 'post', 'user', 'activity']).default('all'),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

const tagFeedSchema = z.object({
  tag: z.string().min(1),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

const subscribeTagSchema = z.object({
  tag: z.string().min(1),
});

const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

module.exports = {
  feedSchema,
  createPostSchema,
  createCommentSchema,
  reportSchema,
  searchSchema,
  tagFeedSchema,
  subscribeTagSchema,
  paginationSchema,
};

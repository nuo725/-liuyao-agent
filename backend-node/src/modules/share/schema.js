// Share Module - Zod Validation Schemas

const { z } = require('zod');

const themeSchema = z.enum(['warm', 'cool', 'dark']).default('warm');

const renderSchema = z.object({
  cardId: z.string().min(1),
  theme: themeSchema,
  text: z.string().max(500).optional(),
  backgroundImageUrl: z.string().url().optional(),
});

const saveSchema = renderSchema;

const publishSchema = z.object({
  cardId: z.string().min(1),
  shareText: z.string().min(1).max(2000),
});

const externalSchema = z.object({
  cardId: z.string().min(1),
  platform: z.enum(['wechat', 'moments', 'generic']).default('generic'),
});

module.exports = {
  renderSchema,
  saveSchema,
  publishSchema,
  externalSchema,
};

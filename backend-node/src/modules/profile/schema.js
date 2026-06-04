// Profile Module - Zod Validation Schemas

const { z } = require('zod');

const updateProfileSchema = z.object({
  username: z.string().min(1).max(20).optional(),
  bio: z.string().max(200).optional(),
  city: z.string().max(50).optional(),
  gender: z.enum(['male', 'female', 'not_disclosed']).optional(),
  birthday: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD').optional(),
});

const updateSettingsSchema = z.object({
  pushEnabled: z.boolean().optional(),
  vibrationEnabled: z.boolean().optional(),
  ambientSoundEnabled: z.boolean().optional(),
  publicProfile: z.boolean().optional(),
});

const checkinCalendarSchema = z.object({
  month: z.string().regex(/^\d{4}-\d{2}$/, 'Month must be YYYY-MM').optional(),
});

const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

const deleteAccountSchema = z.object({
  confirmText: z.literal('注销', {
    errorMap: () => ({ message: '请输入"注销"确认' }),
  }),
});

const mediaRefSchema = z.object({
  mediaId: z.string().min(1),
});

module.exports = {
  updateProfileSchema,
  updateSettingsSchema,
  checkinCalendarSchema,
  paginationSchema,
  deleteAccountSchema,
  mediaRefSchema,
};

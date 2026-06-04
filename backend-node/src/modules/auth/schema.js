// Auth Module - Zod Validation Schemas

const { z } = require('zod');

const sendCodeSchema = z.object({
  phone: z.string().regex(/^1[3-9]\d{9}$/, 'Invalid phone number'),
});

const phoneLoginSchema = z.object({
  phone: z.string().regex(/^1[3-9]\d{9}$/, 'Invalid phone number'),
  code: z.string().length(6, 'Verification code must be 6 digits'),
  agreementVersion: z.string().optional(),
  privacyVersion: z.string().optional(),
  consentedAt: z.string().datetime().optional(),
});

const socialLoginSchema = z.object({
  provider: z.enum(['wechat', 'qq']),
  authCode: z.string().min(1, 'Auth code required'),
  agreementVersion: z.string().optional(),
  privacyVersion: z.string().optional(),
  consentedAt: z.string().datetime().optional(),
});

const passwordRecoverySchema = z.object({
  phone: z.string().regex(/^1[3-9]\d{9}$/, 'Invalid phone number'),
  code: z.string().length(6),
  newPassword: z.string().min(8, 'Password must be at least 8 characters'),
  confirmPassword: z.string().min(8),
}).refine((data) => data.newPassword === data.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
});

const guestUpgradeSchema = z.object({
  phone: z.string().regex(/^1[3-9]\d{9}$/, 'Invalid phone number'),
  code: z.string().length(6),
});

const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token required'),
});

module.exports = {
  sendCodeSchema,
  phoneLoginSchema,
  socialLoginSchema,
  passwordRecoverySchema,
  guestUpgradeSchema,
  refreshTokenSchema,
};

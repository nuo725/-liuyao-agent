// Auth Module - Business Logic Service

const { randomUUID } = require('crypto');
const { createHash } = require('crypto');
const bcrypt = require('bcryptjs');
const { getPrisma } = require('../../db/prisma');
const { getEnv } = require('../../config/env');
const { generateTokens } = require('../../middleware/auth');
const { ApiError } = require('../../shared/api-error');
const { createLogger } = require('../../shared/logger');

const logger = createLogger('auth-service');

// In-memory verification code store (production: use Redis or DB)
const _codeStore = new Map();

/**
 * Generate and "send" a verification code.
 * In test mode, always uses 123456.
 */
async function sendVerificationCode(phone) {
  const env = getEnv();
  const code = env.SMS_PROVIDER === 'test' ? '123456' : generateCode();

  // Store with 5-minute TTL
  _codeStore.set(phone, {
    code,
    expiresAt: Date.now() + 5 * 60 * 1000,
    attempts: 0,
  });

  logger.info({ phone: maskPhone(phone) }, 'Verification code generated');

  // TODO: Integrate real SMS provider (Aliyun/Twilio)
  if (env.SMS_PROVIDER !== 'test') {
    logger.warn('Real SMS provider not implemented, code stored only');
  }

  return { sent: true, ttl: 300 };
}

/**
 * Verify a code and login/register the user.
 */
async function phoneLogin(phone, code, agreementInfo) {
  const prisma = getPrisma();

  // Verify code
  const stored = _codeStore.get(phone);
  if (!stored) {
    throw ApiError.badRequest('No verification code requested for this phone');
  }
  if (Date.now() > stored.expiresAt) {
    _codeStore.delete(phone);
    throw ApiError.badRequest('Verification code expired');
  }
  if (stored.attempts >= 5) {
    _codeStore.delete(phone);
    throw ApiError.rateLimited('Too many verification attempts');
  }
  if (stored.code !== code) {
    stored.attempts++;
    throw ApiError.badRequest('Invalid verification code');
  }

  // Code valid, clean up
  _codeStore.delete(phone);

  // Find or create user
  let user = await prisma.user.findUnique({ where: { phone } });
  const isNewUser = !user;

  if (!user) {
    user = await prisma.user.create({
      data: {
        phone,
        username: `用户${phone.slice(-4)}`,
        shortId: `u_${randomUUID().slice(0, 8)}`,
      },
    });

    // Create profile settings
    await prisma.profileSettings.create({
      data: { userId: user.id },
    });

    // Create credit account
    await prisma.creditAccount.create({
      data: { userId: user.id },
    });

    logger.info({ userId: user.id }, 'New user created');
  }

  // Record agreement consent
  if (agreementInfo?.agreementVersion && agreementInfo?.privacyVersion) {
    await prisma.agreementConsent.create({
      data: {
        userId: user.id,
        agreementVersion: agreementInfo.agreementVersion,
        privacyVersion: agreementInfo.privacyVersion,
        consentedAt: agreementInfo.consentedAt ? new Date(agreementInfo.consentedAt) : new Date(),
      },
    });
  }

  // Generate tokens
  const tokens = generateTokens(user.id);

  // Store refresh token hash
  const refreshTokenHash = await bcrypt.hash(tokens.refreshToken, 10);
  await prisma.authSession.create({
    data: {
      userId: user.id,
      refreshTokenHash,
      expiresAt: new Date(tokens.refreshExpiresAt),
    },
  });

  logger.info({ userId: user.id, isNewUser }, 'Phone login successful');

  return {
    user: formatUser(user),
    ...tokens,
    isNewUser,
  };
}

/**
 * Restore session from a valid access token.
 */
async function restoreSession(userId) {
  const prisma = getPrisma();
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user || user.status === 'deleted') {
    throw ApiError.unauthorized('User not found or deleted');
  }
  return { user: formatUser(user) };
}

/**
 * Refresh access token using a refresh token.
 */
async function refreshSession(refreshToken) {
  const prisma = getPrisma();
  const env = getEnv();
  const jwt = require('jsonwebtoken');

  // Verify the refresh token
  let payload;
  try {
    payload = jwt.verify(refreshToken, env.JWT_SECRET);
  } catch {
    throw ApiError.sessionExpired('Invalid refresh token');
  }

  if (payload.type !== 'refresh') {
    throw ApiError.badRequest('Not a refresh token');
  }

  // Find the session
  const sessions = await prisma.authSession.findMany({
    where: { userId: payload.sub, revokedAt: null },
  });

  let matchedSession = null;
  for (const session of sessions) {
    if (await bcrypt.compare(refreshToken, session.refreshTokenHash)) {
      matchedSession = session;
      break;
    }
  }

  if (!matchedSession) {
    throw ApiError.sessionExpired('Refresh token not found or revoked');
  }

  // Check expiration
  if (new Date() > matchedSession.expiresAt) {
    throw ApiError.sessionExpired('Refresh token expired');
  }

  // Revoke old session
  await prisma.authSession.update({
    where: { id: matchedSession.id },
    data: { revokedAt: new Date() },
  });

  // Generate new tokens
  const tokens = generateTokens(payload.sub);
  const refreshTokenHash = await bcrypt.hash(tokens.refreshToken, 10);
  await prisma.authSession.create({
    data: {
      userId: payload.sub,
      refreshTokenHash,
      expiresAt: new Date(tokens.refreshExpiresAt),
    },
  });

  const user = await prisma.user.findUnique({ where: { id: payload.sub } });

  return {
    user: formatUser(user),
    ...tokens,
  };
}

/**
 * Logout: revoke current session.
 */
async function logout(userId, refreshToken) {
  const prisma = getPrisma();

  if (refreshToken) {
    const sessions = await prisma.authSession.findMany({
      where: { userId, revokedAt: null },
    });

    for (const session of sessions) {
      if (await bcrypt.compare(refreshToken, session.refreshTokenHash)) {
        await prisma.authSession.update({
          where: { id: session.id },
          data: { revokedAt: new Date() },
        });
        break;
      }
    }
  }

  logger.info({ userId }, 'User logged out');
  return { loggedOut: true };
}

/**
 * Upgrade guest account to registered account.
 */
async function upgradeGuest(userId, phone, code) {
  const prisma = getPrisma();

  // Verify code
  const stored = _codeStore.get(phone);
  if (!stored || stored.code !== code) {
    throw ApiError.badRequest('Invalid verification code');
  }
  if (Date.now() > stored.expiresAt) {
    _codeStore.delete(phone);
    throw ApiError.badRequest('Verification code expired');
  }
  _codeStore.delete(phone);

  // Check if phone is already taken
  const existing = await prisma.user.findUnique({ where: { phone } });
  if (existing && existing.id !== userId) {
    throw ApiError.conflict('Phone number already registered');
  }

  // Update user
  const user = await prisma.user.update({
    where: { id: userId },
    data: { phone },
  });

  logger.info({ userId }, 'Guest account upgraded');
  return { user: formatUser(user) };
}

/**
 * Social login through a provider adapter.
 */
async function socialLogin(provider, authCode, agreementInfo) {
  const prisma = getPrisma();
  const profile = resolveSocialProfile(provider, authCode);

  let socialAccount = await prisma.socialAccount.findUnique({
    where: { provider_openId: { provider, openId: profile.openId } },
    include: { user: true },
  });

  let user = socialAccount?.user;
  const isNewUser = !user;

  if (!user) {
    user = await prisma.user.create({
      data: {
        username: profile.nickname || `${provider}用户`,
        avatarUrl: profile.avatarUrl || '',
        shortId: `s_${randomUUID().slice(0, 8)}`,
        socialAccounts: {
          create: {
            provider,
            openId: profile.openId,
            unionId: profile.unionId || null,
            nickname: profile.nickname || '',
            avatarUrl: profile.avatarUrl || '',
          },
        },
        profileSettings: { create: {} },
        creditAccount: { create: {} },
      },
    });
  } else {
    await prisma.socialAccount.update({
      where: { provider_openId: { provider, openId: profile.openId } },
      data: {
        unionId: profile.unionId || socialAccount.unionId,
        nickname: profile.nickname || socialAccount.nickname,
        avatarUrl: profile.avatarUrl || socialAccount.avatarUrl,
      },
    });
  }

  if (agreementInfo?.agreementVersion && agreementInfo?.privacyVersion) {
    await prisma.agreementConsent.create({
      data: {
        userId: user.id,
        agreementVersion: agreementInfo.agreementVersion,
        privacyVersion: agreementInfo.privacyVersion,
        consentedAt: agreementInfo.consentedAt ? new Date(agreementInfo.consentedAt) : new Date(),
      },
    });
  }

  const tokens = generateTokens(user.id);
  const refreshTokenHash = await bcrypt.hash(tokens.refreshToken, 10);
  await prisma.authSession.create({
    data: {
      userId: user.id,
      refreshTokenHash,
      expiresAt: new Date(tokens.refreshExpiresAt),
    },
  });

  logger.info({ userId: user.id, provider, isNewUser }, 'Social login successful');

  return {
    user: formatUser(user),
    ...tokens,
    isNewUser,
    provider,
  };
}

// ─────────────── Helpers ───────────────

function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function maskPhone(phone) {
  if (!phone || phone.length < 7) return '***';
  return phone.slice(0, 3) + '****' + phone.slice(-4);
}

function formatUser(user) {
  return {
    id: user.id,
    username: user.username,
    bio: user.bio,
    avatarUrl: user.avatarUrl,
    coverUrl: user.coverUrl,
    shortId: user.shortId,
    city: user.city,
    gender: user.gender,
    birthday: user.birthday,
    createdAt: user.createdAt,
  };
}

function resolveSocialProfile(provider, authCode) {
  const env = getEnv();
  if (env.NODE_ENV === 'production') {
    throw ApiError.badRequest(`${provider} OAuth adapter is not configured`);
  }

  const normalized = String(authCode).replace(/^mock:/, '');
  const digest = createHash('sha256').update(`${provider}:${normalized}`).digest('hex');
  return {
    openId: `${provider}_${digest.slice(0, 24)}`,
    unionId: `${provider}_union_${digest.slice(24, 36)}`,
    nickname: `${provider.toUpperCase()}用户${digest.slice(0, 4)}`,
    avatarUrl: '',
  };
}

module.exports = {
  sendVerificationCode,
  phoneLogin,
  restoreSession,
  refreshSession,
  logout,
  upgradeGuest,
  socialLogin,
};

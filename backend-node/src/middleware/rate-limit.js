// Zhouyi Backend - Rate Limit Middleware (BE-013)
// Per-user/IP, per-action rate limiting with configurable window and max.

const { ApiError } = require('../shared/api-error');
const { getEnv } = require('../config/env');
const { getPrisma } = require('../db/prisma');

const _counters = new Map();

function rateLimit(action, maxRequests = 60, windowSeconds = 60) {
  return async (req, res, next) => {
    try {
      const identifier = getIdentifier(req);
      const env = getEnv();
      const result = env.RATE_LIMIT_STORE === 'database'
        ? await consumeDatabaseBucket(identifier, action, maxRequests, windowSeconds)
        : consumeMemoryBucket(_counters, identifier, action, maxRequests, windowSeconds);

      res.setHeader('X-RateLimit-Limit', String(maxRequests));
      res.setHeader('X-RateLimit-Remaining', String(result.remaining));
      res.setHeader('X-RateLimit-Reset', result.resetAt.toISOString());

      next();
    } catch (err) {
      next(err);
    }
  };
}

function getIdentifier(req) {
  if (req.userId) return `user:${req.userId}`;
  const forwarded = String(req.headers?.['x-forwarded-for'] || '').split(',')[0].trim();
  return `ip:${forwarded || req.ip || req.socket?.remoteAddress || 'anonymous'}`;
}

function consumeMemoryBucket(store, identifier, action, maxRequests, windowSeconds, now = Date.now()) {
  const key = `${identifier}:${action}`;
  const windowMs = windowSeconds * 1000;
  let entry = store.get(key);
  if (!entry || now >= entry.resetAt.getTime()) {
    entry = {
      count: 0,
      resetAt: new Date(now + windowMs),
    };
    store.set(key, entry);
  }

  entry.count += 1;
  if (entry.count > maxRequests) {
    throw ApiError.rateLimited();
  }

  return {
    count: entry.count,
    remaining: Math.max(maxRequests - entry.count, 0),
    resetAt: entry.resetAt,
  };
}

async function consumeDatabaseBucket(identifier, action, maxRequests, windowSeconds, now = new Date()) {
  const prisma = getPrisma();
  const windowMs = windowSeconds * 1000;
  const expiresAt = new Date(now.getTime() + windowMs);

  return prisma.$transaction(async (tx) => {
    const current = await tx.rateLimitBucket.findUnique({
      where: { identifier_action: { identifier, action } },
    });

    if (!current || now >= current.expiresAt) {
      const bucket = await tx.rateLimitBucket.upsert({
        where: { identifier_action: { identifier, action } },
        update: {
          count: 1,
          windowStart: now,
          expiresAt,
        },
        create: {
          identifier,
          action,
          count: 1,
          windowStart: now,
          expiresAt,
        },
      });
      return {
        count: bucket.count,
        remaining: maxRequests - bucket.count,
        resetAt: bucket.expiresAt,
      };
    }

    if (current.count >= maxRequests) {
      throw ApiError.rateLimited();
    }

    const bucket = await tx.rateLimitBucket.update({
      where: { id: current.id },
      data: { count: { increment: 1 } },
    });

    return {
      count: bucket.count,
      remaining: Math.max(maxRequests - bucket.count, 0),
      resetAt: bucket.expiresAt,
    };
  });
}

module.exports = {
  rateLimit,
  consumeMemoryBucket,
  consumeDatabaseBucket,
  getIdentifier,
};

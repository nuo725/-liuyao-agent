// Zhouyi Backend - Auth Middleware (BE-006)
// JWT Access Token verification.
// Modes: required (reject if no valid token), optional (attach user if token present).

const jwt = require('jsonwebtoken');
const { getEnv } = require('../config/env');
const { getPrisma } = require('../db/prisma');
const { ApiError } = require('../shared/api-error');

const DEMO_USER_ID = 'user_demo';

function extractToken(req) {
  const header = req.headers.authorization;
  if (header && header.startsWith('Bearer ')) {
    return header.slice(7).trim();
  }
  return null;
}

function verifyToken(token) {
  const env = getEnv();
  try {
    return jwt.verify(token, env.JWT_SECRET);
  } catch {
    return null;
  }
}

/**
 * Required auth: rejects with 40101 if no valid token.
 */
function requireAuth(req, res, next) {
  const token = extractToken(req);
  if (!token) {
    throw ApiError.unauthorized();
  }
  const payload = verifyToken(token);
  if (!payload) {
    throw ApiError.sessionExpired();
  }
  req.userId = payload.sub;
  req.authPayload = payload;
  next();
}

function requireRole(roles) {
  const allowedRoles = Array.isArray(roles) ? roles : [roles];
  return async (req, res, next) => {
    try {
      if (!req.userId) {
        throw ApiError.unauthorized();
      }
      const prisma = getPrisma();
      const user = await prisma.user.findUnique({
        where: { id: req.userId },
        select: { role: true, status: true },
      });
      if (!user || user.status === 'deleted') {
        throw ApiError.unauthorized('User not found or deleted');
      }
      if (!allowedRoles.includes(user.role)) {
        throw ApiError.forbidden('Insufficient role');
      }
      req.userRole = user.role;
      next();
    } catch (err) {
      next(err);
    }
  };
}

/**
 * Optional auth: attaches userId if token present, falls back to demo user.
 */
function optionalAuth(req, res, next) {
  const token = extractToken(req);
  if (token) {
    const payload = verifyToken(token);
    if (payload) {
      req.userId = payload.sub;
      req.authPayload = payload;
      return next();
    }
  }
  req.userId = DEMO_USER_ID;
  next();
}

/**
 * Generate access + refresh token pair.
 */
function generateTokens(userId) {
  const env = getEnv();
  const accessToken = jwt.sign({ sub: userId }, env.JWT_SECRET, {
    expiresIn: env.JWT_ACCESS_TTL,
  });
  const refreshToken = jwt.sign({ sub: userId, type: 'refresh' }, env.JWT_SECRET, {
    expiresIn: env.JWT_REFRESH_TTL,
  });
  const expiresAt = new Date(Date.now() + env.JWT_ACCESS_TTL * 1000).toISOString();
  const refreshExpiresAt = new Date(Date.now() + env.JWT_REFRESH_TTL * 1000).toISOString();
  return { accessToken, refreshToken, expiresAt, refreshExpiresAt };
}

module.exports = { requireAuth, optionalAuth, requireRole, generateTokens, DEMO_USER_ID };

// Zhouyi Backend - Rate Limit Middleware (BE-013)
// Per-user, per-action rate limiting with configurable window and max.

const { ApiError } = require('../shared/api-error');

const _counters = new Map();

function rateLimit(action, maxRequests = 60, windowSeconds = 60) {
  return (req, res, next) => {
    const userId = req.userId || req.ip || 'anonymous';
    const key = `${userId}:${action}`;
    const now = Date.now();
    const windowMs = windowSeconds * 1000;

    let entry = _counters.get(key);
    if (!entry || now - entry.start > windowMs) {
      entry = { start: now, count: 0 };
      _counters.set(key, entry);
    }

    entry.count++;
    if (entry.count > maxRequests) {
      throw ApiError.rateLimited();
    }

    next();
  };
}

module.exports = { rateLimit };

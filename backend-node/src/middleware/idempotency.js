// Zhouyi Backend - Idempotency Middleware (BE-013)
// Stores response by Idempotency-Key to avoid duplicate processing.

const { createLogger } = require('../shared/logger');
const logger = createLogger('idempotency');

const _cache = new Map(); // In-memory; production should use DB table

function idempotency(req, res, next) {
  const key = req.headers['idempotency-key'];
  if (!key || req.method === 'GET') return next();

  const userId = req.userId || 'anonymous';
  const cacheKey = `${userId}:${key}`;

  if (_cache.has(cacheKey)) {
    const cached = _cache.get(cacheKey);
    logger.debug({ key, requestId: req.requestId }, 'Idempotent replay');
    return res.status(cached.status).json(cached.body);
  }

  // Intercept json() to cache response
  const originalJson = res.json.bind(res);
  res.json = (body) => {
    if (res.statusCode < 400) {
      _cache.set(cacheKey, { status: res.statusCode, body, timestamp: Date.now() });
      // Evict after 1 hour
      setTimeout(() => _cache.delete(cacheKey), 3600_000);
    }
    return originalJson(body);
  };

  next();
}

module.exports = { idempotency };

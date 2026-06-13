// Zhouyi Backend - Idempotency Middleware (BE-013)
// Stores response by Idempotency-Key to avoid duplicate processing.

const crypto = require('crypto');
const { createLogger } = require('../shared/logger');
const logger = createLogger('idempotency');

const memoryRecords = new Map();
const DEFAULT_TTL_MS = 3600_000;

function stableStringify(value) {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map((item) => stableStringify(item)).join(',')}]`;
  }
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(',')}}`;
}

function hashRequest(req) {
  const payload = {
    method: req.method,
    path: req.originalUrl || req.path || '',
    body: req.body || null,
    query: req.query || null,
  };
  return crypto.createHash('sha256').update(stableStringify(payload)).digest('hex');
}

function getScope(req) {
  return `${req.method}:${req.baseUrl || ''}${req.path || req.originalUrl || ''}`;
}

function normalizeStoredResponse(record) {
  if (!record?.response) return null;
  return {
    requestHash: record.requestHash || null,
    response: record.response,
  };
}

function createMemoryStore() {
  return {
    hashRequest,
    async get({ userId, scope, key }) {
      const cacheKey = `${userId}:${scope}:${key}`;
      const record = memoryRecords.get(cacheKey);
      if (!record) return null;
      if (record.expiresAt <= Date.now()) {
        memoryRecords.delete(cacheKey);
        return null;
      }
      return normalizeStoredResponse(record);
    },
    async set({ userId, scope, key, requestHash, response, ttlMs }) {
      const cacheKey = `${userId}:${scope}:${key}`;
      memoryRecords.set(cacheKey, {
        requestHash,
        response,
        expiresAt: Date.now() + ttlMs,
      });
      const evictionTimer = setTimeout(() => memoryRecords.delete(cacheKey), ttlMs);
      if (typeof evictionTimer.unref === 'function') {
        evictionTimer.unref();
      }
    },
  };
}

function createPrismaStore() {
  return {
    hashRequest,
    async get({ userId, scope, key }) {
      const { getPrisma } = require('../db/prisma');
      const prisma = getPrisma();
      const record = await prisma.idempotencyKey.findUnique({
        where: {
          userId_scope_key: { userId, scope, key },
        },
      });
      if (!record) return null;
      if (record.expiresAt <= new Date()) {
        await prisma.idempotencyKey.delete({ where: { id: record.id } }).catch(() => {});
        return null;
      }
      if (!record.responseBody) return null;
      return normalizeStoredResponse({
        requestHash: record.requestHash,
        response: record.responseBody,
      });
    },
    async set({ userId, scope, key, requestHash, response, ttlMs }) {
      const { getPrisma } = require('../db/prisma');
      const prisma = getPrisma();
      await prisma.idempotencyKey.upsert({
        where: {
          userId_scope_key: { userId, scope, key },
        },
        update: {
          requestHash,
          responseBody: response,
          expiresAt: new Date(Date.now() + ttlMs),
        },
        create: {
          userId,
          scope,
          key,
          requestHash,
          responseBody: response,
          expiresAt: new Date(Date.now() + ttlMs),
        },
      });
    },
  };
}

function createDefaultStore() {
  const mode = process.env.IDEMPOTENCY_STORE || (process.env.NODE_ENV === 'production' ? 'database' : 'memory');
  return mode === 'database' ? createPrismaStore() : createMemoryStore();
}

function createIdempotency(options = {}) {
  const store = options.store || createDefaultStore();
  const ttlMs = options.ttlMs || DEFAULT_TTL_MS;

  return async function idempotencyMiddleware(req, res, next) {
    const key = req.headers['idempotency-key'];
    if (!key || req.method === 'GET') return next();

    const userId = req.userId || 'anonymous';
    const scope = getScope(req);
    const requestHash = typeof store.hashRequest === 'function' ? store.hashRequest(req) : hashRequest(req);

    let cached = null;
    try {
      cached = await store.get({ userId, scope, key, requestHash });
    } catch (err) {
      logger.warn({ err, key, requestId: req.requestId }, 'Idempotency store read failed; processing request');
    }

    if (cached?.response) {
      logger.debug({ key, requestId: req.requestId }, 'Idempotent replay');
      return res.status(cached.response.status).json(cached.response.body);
    }

    // Intercept json() to cache response.
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      if (res.statusCode < 400) {
        const response = { status: res.statusCode || 200, body };
        return Promise.resolve(store.set({ userId, scope, key, requestHash, response, ttlMs }))
          .then(() => originalJson(body))
          .catch((err) => {
            logger.warn({ err, key, requestId: req.requestId }, 'Idempotency store write failed');
            return originalJson(body);
          });
      }
      return originalJson(body);
    };

    next();
  };
}

const idempotency = createIdempotency();

module.exports = {
  createIdempotency,
  createMemoryStore,
  createPrismaStore,
  idempotency,
};

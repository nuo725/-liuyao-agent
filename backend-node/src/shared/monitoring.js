const { getPrisma } = require('../db/prisma');

const metrics = {
  startedAt: new Date(),
  requests: 0,
  errors: 0,
  totalDurationMs: 0,
  routes: new Map(),
};

function metricsMiddleware(req, res, next) {
  const started = process.hrtime.bigint();
  res.on('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - started) / 1_000_000;
    recordRequest({
      method: req.method,
      path: normalizePath(req.originalUrl || req.url),
      statusCode: res.statusCode,
      durationMs,
    });
  });
  next();
}

function recordRequest({ method, path, statusCode, durationMs }) {
  const key = `${method} ${path}`;
  const route = metrics.routes.get(key) || {
    method,
    path,
    count: 0,
    errors: 0,
    totalDurationMs: 0,
    maxDurationMs: 0,
    statusCodes: {},
  };

  route.count += 1;
  route.totalDurationMs += durationMs;
  route.maxDurationMs = Math.max(route.maxDurationMs, durationMs);
  route.statusCodes[statusCode] = (route.statusCodes[statusCode] || 0) + 1;
  if (statusCode >= 500) {
    route.errors += 1;
    metrics.errors += 1;
  }

  metrics.requests += 1;
  metrics.totalDurationMs += durationMs;
  metrics.routes.set(key, route);
}

function snapshotMetrics() {
  const routes = [...metrics.routes.values()].map((route) => ({
    ...route,
    avgDurationMs: round(route.totalDurationMs / route.count),
    maxDurationMs: round(route.maxDurationMs),
    totalDurationMs: round(route.totalDurationMs),
  }));

  return {
    startedAt: metrics.startedAt.toISOString(),
    uptimeSec: round(process.uptime()),
    requests: metrics.requests,
    errors: metrics.errors,
    errorRate: metrics.requests ? round(metrics.errors / metrics.requests) : 0,
    avgDurationMs: metrics.requests ? round(metrics.totalDurationMs / metrics.requests) : 0,
    routes,
  };
}

async function readinessCheck() {
  const checks = {
    app: { status: 'ok' },
    db: { status: 'unknown' },
  };

  try {
    const prisma = getPrisma();
    await prisma.$queryRaw`SELECT 1`;
    checks.db.status = 'ok';
  } catch (err) {
    checks.db.status = 'error';
    checks.db.message = err.code || err.message || 'Database unavailable';
  }

  const ready = Object.values(checks).every((check) => check.status === 'ok');
  return {
    ready,
    status: ready ? 'ok' : 'degraded',
    time: new Date().toISOString(),
    checks,
  };
}

function resetMetrics() {
  metrics.startedAt = new Date();
  metrics.requests = 0;
  metrics.errors = 0;
  metrics.totalDurationMs = 0;
  metrics.routes.clear();
}

function normalizePath(value) {
  return String(value || '/').split('?')[0] || '/';
}

function round(value) {
  return Math.round(value * 100) / 100;
}

module.exports = {
  metricsMiddleware,
  recordRequest,
  snapshotMetrics,
  readinessCheck,
  resetMetrics,
};

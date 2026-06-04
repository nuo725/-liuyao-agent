// Zhouyi Backend - Express App Factory (BE-001)
// Separated from server.js so tests can import without starting the listener.

const express = require('express');
const cors = require('cors');
const path = require('path');
const { requestIdMiddleware } = require('./middleware/request-id');
const { errorHandler } = require('./middleware/error-handler');
const { ok, fail } = require('./shared/response');
const { metricsMiddleware, readinessCheck, snapshotMetrics } = require('./shared/monitoring');

// Module routes
const authRoutes = require('./modules/auth/route');
const profileRoutes = require('./modules/profile/route');
const creditRoutes = require('./modules/credits/route');
const billingRoutes = require('./modules/billing/route');
const ritualRoutes = require('./modules/ritual/route');
const communityRoutes = require('./modules/community/route');
const notificationRoutes = require('./modules/notifications/route');
const matchRoutes = require('./modules/match/route');
const activityRoutes = require('./modules/activities/route');
const shareRoutes = require('./modules/share/route');
const supportRoutes = require('./modules/support/route');
const mediaRoutes = require('./modules/media/route');
const analyticsRoutes = require('./modules/analytics/route');
const adminRoutes = require('./modules/admin/route');

function createApp() {
  const app = express();

  // Global middleware
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));
  app.use(requestIdMiddleware);
  app.use(metricsMiddleware);
  app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

  // Health check
  app.get('/api/v1/health', async (req, res) => {
    try {
      const { getPrisma } = require('./db/prisma');
      const prisma = getPrisma();
      await prisma.$queryRaw`SELECT 1`;
      res.json(ok({ status: 'ok', db: 'connected', time: new Date().toISOString() }));
    } catch {
      res.status(503).json(ok({ status: 'degraded', db: 'disconnected', time: new Date().toISOString() }));
    }
  });

  app.get('/api/v1/ready', async (req, res) => {
    const result = await readinessCheck();
    res.status(result.ready ? 200 : 503).json(ok(result));
  });

  app.get('/api/v1/metrics', (req, res) => {
    res.json(ok(snapshotMetrics()));
  });

  // Module routes
  app.use('/api/v1/auth', authRoutes);
  app.use('/api/v1/profile', profileRoutes);
  app.use('/api/v1/credits', creditRoutes);
  app.use('/api/v1/billing', billingRoutes);
  app.use('/api/v1/ritual', ritualRoutes);
  app.use('/api/v1/community', communityRoutes);
  app.use('/api/v1/notifications', notificationRoutes);
  app.use('/api/v1/match', matchRoutes);
  app.use('/api/v1/activities', activityRoutes);
  app.use('/api/v1/share', shareRoutes);
  app.use('/api/v1/support', supportRoutes);
  app.use('/api/v1/media', mediaRoutes);
  app.use('/api/v1/analytics', analyticsRoutes);
  app.use('/api/v1/admin', adminRoutes);

  // 404 fallback
  app.use((req, res) => {
    res.status(404).json({
      ...fail('40401', `Route not implemented: ${req.method} ${req.path}`),
      requestId: req.requestId,
    });
  });

  // Error handler (must be last)
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };

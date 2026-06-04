// Admin Module Routes (OPS-005)
// Feature flags management, system status

const { Router } = require('express');
const { ok } = require('../../shared/response');
const { requireAuth } = require('../../middleware/auth');
const { getAllFlags, setFlag } = require('../../shared/feature-flags');
const { createLogger } = require('../../shared/logger');

const router = Router();
const logger = createLogger('admin');

// Admin middleware — only allow users with admin role
function requireAdmin(req, res, next) {
  // TODO: Implement proper role check
  // For now, allow any authenticated user (restrict in production)
  if (!req.userId) {
    const { ApiError } = require('../../shared/api-error');
    throw ApiError.unauthorized();
  }
  next();
}

// GET /feature-flags - List all feature flags
router.get('/feature-flags', requireAuth, requireAdmin, (req, res) => {
  const flags = getAllFlags();
  res.json(ok(flags));
});

// PUT /feature-flags/:flagName - Update a feature flag
router.put('/feature-flags/:flagName', requireAuth, requireAdmin, (req, res, next) => {
  try {
    const { flagName } = req.params;
    const { enabled } = req.body;

    if (typeof enabled !== 'boolean') {
      const { ApiError } = require('../../shared/api-error');
      throw ApiError.badRequest('enabled must be a boolean');
    }

    setFlag(flagName, enabled);
    logger.warn({ flag: flagName, enabled, userId: req.userId }, 'Feature flag toggled by admin');

    res.json(ok({ flag: flagName, enabled }));
  } catch (err) {
    next(err);
  }
});

// GET /system/status - System status overview
router.get('/system/status', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const { getPrisma } = require('../../db/prisma');
    const prisma = getPrisma();

    const [userCount, postCount, sessionCount] = await Promise.all([
      prisma.user.count({ where: { status: 'active' } }),
      prisma.communityPost.count({ where: { status: 'published' } }),
      prisma.ritualSession.count(),
    ]);

    res.json(ok({
      users: userCount,
      posts: postCount,
      sessions: sessionCount,
      flags: getAllFlags(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
    }));
  } catch (err) {
    next(err);
  }
});

module.exports = router;

// Feature Flags Module (OPS-005)
// Centralized feature toggle management for safe rollout and rollback.
// Flags can be overridden via environment variables for emergency rollback.

const { createLogger } = require('./logger');
const logger = createLogger('feature-flags');

// Default flag definitions — all P0 features enabled by default
const DEFAULT_FLAGS = {
  community_publish_enabled: { default: true, description: '社区发布功能' },
  community_comment_enabled: { default: true, description: '社区评论功能' },
  match_enabled: { default: true, description: '同频匹配功能' },
  activity_join_enabled: { default: true, description: '活动报名功能' },
  billing_enabled: { default: true, description: '会员与订单功能' },
  ritual_enabled: { default: true, description: '仪式会话功能' },
  notification_push_enabled: { default: true, description: '推送通知功能' },
  social_login_enabled: { default: false, description: '社交登录（微信/QQ）' },
  media_upload_enabled: { default: true, description: '媒体上传功能' },
  share_card_enabled: { default: true, description: '分享卡功能' },
};

// In-memory flag store (production: use Redis or config service)
const _flags = {};

/**
 * Initialize flags from environment variables or defaults.
 * Env override format: FEATURE_<FLAG_NAME>=true|false
 */
function initFlags() {
  for (const [key, config] of Object.entries(DEFAULT_FLAGS)) {
    const envKey = `FEATURE_${key.toUpperCase()}`;
    const envVal = process.env[envKey];

    if (envVal !== undefined) {
      _flags[key] = envVal === 'true' || envVal === '1';
      logger.info({ flag: key, value: _flags[key], source: 'env' }, 'Feature flag loaded from env');
    } else {
      _flags[key] = config.default;
    }
  }
  logger.info({ flags: Object.keys(_flags).length }, 'Feature flags initialized');
}

/**
 * Check if a feature is enabled.
 */
function isEnabled(flagName) {
  if (_flags[flagName] === undefined) {
    logger.warn({ flag: flagName }, 'Unknown feature flag, returning false');
    return false;
  }
  return _flags[flagName];
}

/**
 * Set a flag value (runtime override).
 */
function setFlag(flagName, value) {
  if (DEFAULT_FLAGS[flagName] === undefined) {
    throw new Error(`Unknown feature flag: ${flagName}`);
  }
  _flags[flagName] = !!value;
  logger.info({ flag: flagName, value: _flags[flagName] }, 'Feature flag updated');
}

/**
 * Get all flags with their current state.
 */
function getAllFlags() {
  const result = {};
  for (const [key, config] of Object.entries(DEFAULT_FLAGS)) {
    result[key] = {
      enabled: _flags[key] ?? config.default,
      description: config.description,
    };
  }
  return result;
}

/**
 * Express middleware to check feature flag before proceeding.
 */
function requireFeature(flagName) {
  return (req, res, next) => {
    if (!isEnabled(flagName)) {
      const { ApiError } = require('./api-error');
      throw ApiError.forbidden(`功能暂未开放: ${DEFAULT_FLAGS[flagName]?.description || flagName}`);
    }
    next();
  };
}

// Initialize on module load
initFlags();

module.exports = { isEnabled, setFlag, getAllFlags, requireFeature, initFlags };

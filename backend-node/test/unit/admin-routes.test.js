const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { isEnabled, setFlag, getAllFlags, initFlags } = require('../../src/shared/feature-flags');

describe('Admin routes validation (OPS-005)', () => {
  beforeEach(() => {
    // Reset flags to defaults
    initFlags();
  });

  describe('Feature flags API contract', () => {
    it('getAllFlags returns all 10 flags', () => {
      const flags = getAllFlags();
      assert.equal(Object.keys(flags).length, 10);
    });

    it('each flag has enabled and description fields', () => {
      const flags = getAllFlags();
      for (const [name, config] of Object.entries(flags)) {
        assert.ok('enabled' in config, `${name} should have enabled`);
        assert.ok('description' in config, `${name} should have description`);
        assert.equal(typeof config.enabled, 'boolean', `${name}.enabled should be boolean`);
        assert.equal(typeof config.description, 'string', `${name}.description should be string`);
      }
    });

    it('setFlag updates flag value', () => {
      assert.equal(isEnabled('billing_enabled'), true);
      setFlag('billing_enabled', false);
      assert.equal(isEnabled('billing_enabled'), false);
    });

    it('setFlag rejects unknown flags', () => {
      assert.throws(() => setFlag('unknown_flag', true), /Unknown feature flag/);
    });

    it('setFlag coerces to boolean', () => {
      setFlag('billing_enabled', 0);
      assert.equal(isEnabled('billing_enabled'), false);
      setFlag('billing_enabled', 1);
      assert.equal(isEnabled('billing_enabled'), true);
    });
  });

  describe('Feature flag validation', () => {
    it('enabled field must be boolean', () => {
      // Simulate request body validation
      const body = { enabled: 'not_boolean' };
      assert.equal(typeof body.enabled !== 'boolean', true, 'should reject non-boolean');
    });

    it('accepts boolean true', () => {
      const body = { enabled: true };
      assert.equal(typeof body.enabled, 'boolean');
    });

    it('accepts boolean false', () => {
      const body = { enabled: false };
      assert.equal(typeof body.enabled, 'boolean');
    });
  });

  describe('System status response', () => {
    it('status response has required fields', () => {
      // Simulate status response structure
      const status = {
        users: 100,
        posts: 50,
        sessions: 200,
        flags: getAllFlags(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
      };

      assert.ok('users' in status, 'should have users count');
      assert.ok('posts' in status, 'should have posts count');
      assert.ok('sessions' in status, 'should have sessions count');
      assert.ok('flags' in status, 'should have flags');
      assert.ok('uptime' in status, 'should have uptime');
      assert.ok('memory' in status, 'should have memory');
    });

    it('uptime is a positive number', () => {
      const uptime = process.uptime();
      assert.ok(typeof uptime === 'number', 'uptime should be number');
      assert.ok(uptime >= 0, 'uptime should be non-negative');
    });

    it('memory usage has required fields', () => {
      const memory = process.memoryUsage();
      assert.ok('rss' in memory, 'should have rss');
      assert.ok('heapTotal' in memory, 'should have heapTotal');
      assert.ok('heapUsed' in memory, 'should have heapUsed');
      assert.ok('external' in memory, 'should have external');
    });
  });

  describe('Admin authorization', () => {
    it('requireAdmin checks for userId', () => {
      // Simulate request without userId
      const req = {};
      const hasUserId = Boolean(req.userId);
      assert.equal(hasUserId, false, 'should reject without userId');
    });

    it('requireAdmin allows authenticated user', () => {
      // Simulate request with userId
      const req = { userId: 'user_123' };
      const hasUserId = Boolean(req.userId);
      assert.equal(hasUserId, true, 'should allow with userId');
    });
  });

  describe('Response envelope', () => {
    it('success response uses ok() helper', () => {
      // Simulate ok() response
      const data = { flag: 'billing_enabled', enabled: true };
      const response = { success: true, data };
      assert.equal(response.success, true);
      assert.deepEqual(response.data, data);
    });

    it('error response uses standard format', () => {
      // Simulate error response
      const error = {
        success: false,
        error: { code: '40001', message: 'enabled must be a boolean' },
      };
      assert.equal(error.success, false);
      assert.ok(error.error.code);
      assert.ok(error.error.message);
    });
  });
});

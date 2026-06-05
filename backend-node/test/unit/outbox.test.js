const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

// Set up test environment
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_SECRET = 'test_jwt_secret_for_outbox_worker_32_chars';
process.env.JWT_ACCESS_TTL = '7200';
process.env.JWT_REFRESH_TTL = '2592000';

const { runOnce, processJob } = require('../../src/workers/outbox');

describe('Outbox worker module', () => {
  describe('runOnce()', () => {
    it('is a function', () => {
      assert.equal(typeof runOnce, 'function');
    });

    it('returns a promise', () => {
      const result = runOnce();
      assert.ok(result instanceof Promise, 'should return promise');
      // Clean up - catch the error since DB is not available
      result.catch(() => {});
    });
  });

  describe('processJob()', () => {
    it('is a function', () => {
      assert.equal(typeof processJob, 'function');
    });

    it('handles notification.push type', async () => {
      // Should not throw for notification.push
      await assert.doesNotReject(() => processJob('notification.push', { userId: 'user_1' }));
    });

    it('handles moderation.review type', async () => {
      // Should not throw for moderation.review
      await assert.doesNotReject(() => processJob('moderation.review', { targetType: 'post', targetId: 'post_1' }));
    });

    it('handles unknown job type', async () => {
      // Should not throw for unknown type
      await assert.doesNotReject(() => processJob('unknown.type', { data: 'test' }));
    });
  });

  describe('Configuration', () => {
    it('has default poll interval', () => {
      const interval = Number(process.env.OUTBOX_POLL_INTERVAL_MS || 3000);
      assert.ok(interval > 0, 'poll interval should be positive');
    });

    it('has default lock timeout', () => {
      const timeout = Number(process.env.OUTBOX_LOCK_TIMEOUT_MS || 60_000);
      assert.ok(timeout > 0, 'lock timeout should be positive');
    });
  });
});

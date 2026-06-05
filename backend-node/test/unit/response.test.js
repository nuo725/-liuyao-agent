const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { ok, fail } = require('../../src/shared/response');

describe('Response module', () => {
  describe('ok()', () => {
    it('returns success envelope with data', () => {
      const result = ok({ id: 'user_1', username: 'test' });
      assert.equal(result.success, true);
      assert.deepEqual(result.data, { id: 'user_1', username: 'test' });
    });

    it('returns success envelope with empty data by default', () => {
      const result = ok();
      assert.equal(result.success, true);
      assert.deepEqual(result.data, {});
    });

    it('returns success envelope with array data', () => {
      const result = ok({ items: [1, 2, 3] });
      assert.equal(result.success, true);
      assert.deepEqual(result.data.items, [1, 2, 3]);
    });

    it('returns success envelope with null data', () => {
      const result = ok(null);
      assert.equal(result.success, true);
      assert.equal(result.data, null);
    });

    it('returns success envelope with nested data', () => {
      const result = ok({
        user: { id: 'user_1', profile: { bio: 'test' } },
        settings: { pushEnabled: true },
      });
      assert.equal(result.success, true);
      assert.ok(result.data.user.profile.bio === 'test');
    });
  });

  describe('fail()', () => {
    it('returns error envelope with code and message', () => {
      const result = fail('40001', 'Invalid request');
      assert.equal(result.success, false);
      assert.equal(result.error.code, '40001');
      assert.equal(result.error.message, 'Invalid request');
    });

    it('returns error envelope with auth error code', () => {
      const result = fail('40101', 'Authentication required');
      assert.equal(result.success, false);
      assert.equal(result.error.code, '40101');
    });

    it('returns error envelope with not found error code', () => {
      const result = fail('40401', 'Resource not found');
      assert.equal(result.success, false);
      assert.equal(result.error.code, '40401');
    });

    it('returns error envelope with internal error code', () => {
      const result = fail('50000', 'Internal server error');
      assert.equal(result.success, false);
      assert.equal(result.error.code, '50000');
    });
  });

  describe('Envelope consistency', () => {
    it('ok and fail have consistent structure', () => {
      const okResult = ok({ data: 'test' });
      const failResult = fail('40001', 'error');

      assert.equal(typeof okResult.success, 'boolean');
      assert.equal(typeof failResult.success, 'boolean');
      assert.ok('data' in okResult);
      assert.ok('error' in failResult);
    });

    it('envelope is JSON serializable', () => {
      const okResult = ok({ items: [1, 2, 3] });
      const json = JSON.stringify(okResult);
      const parsed = JSON.parse(json);
      assert.equal(parsed.success, true);
      assert.deepEqual(parsed.data.items, [1, 2, 3]);
    });

    it('fail envelope is JSON serializable', () => {
      const failResult = fail('40001', 'Invalid request');
      const json = JSON.stringify(failResult);
      const parsed = JSON.parse(json);
      assert.equal(parsed.success, false);
      assert.equal(parsed.error.code, '40001');
    });
  });
});

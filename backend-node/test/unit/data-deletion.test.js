const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { maskPhone, getDeletionOperations, getExportQueries } = require('../../scripts/data-deletion');

describe('data-deletion', () => {
  describe('maskPhone', () => {
    it('masks middle digits of a phone number', () => {
      assert.equal(maskPhone('13812345678'), '138****5678');
    });

    it('returns *** for short phone numbers', () => {
      assert.equal(maskPhone('123456'), '***');
      assert.equal(maskPhone('12'), '***');
    });

    it('returns *** for null/undefined', () => {
      assert.equal(maskPhone(null), '***');
      assert.equal(maskPhone(undefined), '***');
      assert.equal(maskPhone(''), '***');
    });

    it('handles 7-digit phone (minimum length)', () => {
      assert.equal(maskPhone('1234567'), '123****4567');
    });
  });

  describe('getDeletionOperations', () => {
    it('returns a non-empty array of named operations', () => {
      const mockPrisma = {};
      const ops = getDeletionOperations(mockPrisma, 'user-1');
      assert.ok(Array.isArray(ops));
      assert.ok(ops.length > 0);
      for (const op of ops) {
        assert.ok(typeof op.name === 'string' && op.name.length > 0);
        assert.ok(typeof op.fn === 'function');
      }
    });

    it('includes all expected deletion targets', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      assert.ok(names.includes('Push tokens'));
      assert.ok(names.includes('Notifications'));
      assert.ok(names.includes('Credit ledger'));
      assert.ok(names.includes('Credit account'));
      assert.ok(names.includes('Ritual sessions'));
      assert.ok(names.includes('Community posts'));
      assert.ok(names.includes('Profile settings'));
      assert.ok(names.includes('Auth sessions'));
    });

    it('deletes child records before parent records (followup messages before ritual sessions)', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      const followupIdx = names.indexOf('Followup messages');
      const cardIdx = names.indexOf('Interpretation cards');
      const ritualIdx = names.indexOf('Ritual sessions');
      assert.ok(followupIdx < ritualIdx, 'Followup messages should be deleted before ritual sessions');
      assert.ok(cardIdx < ritualIdx, 'Interpretation cards should be deleted before ritual sessions');
    });

    it('deletes credit ledger before credit account', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      assert.ok(names.indexOf('Credit ledger') < names.indexOf('Credit account'));
    });
  });

  describe('getExportQueries', () => {
    it('returns a non-empty array of named queries', () => {
      const mockPrisma = {};
      const queries = getExportQueries(mockPrisma, 'user-1');
      assert.ok(Array.isArray(queries));
      assert.ok(queries.length > 0);
      for (const q of queries) {
        assert.ok(typeof q.name === 'string' && q.name.length > 0);
        assert.ok(typeof q.query === 'function');
      }
    });

    it('covers all major data categories', () => {
      const queries = getExportQueries({}, 'user-1');
      const names = queries.map((q) => q.name);
      assert.ok(names.includes('User profile'));
      assert.ok(names.includes('Credit account'));
      assert.ok(names.includes('Ritual sessions'));
      assert.ok(names.includes('Community posts'));
      assert.ok(names.includes('Notifications'));
      assert.ok(names.includes('Orders'));
      assert.ok(names.includes('Media assets'));
    });
  });
});

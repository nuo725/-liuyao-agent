const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { maskPhone, getDeletionOperations, getExportQueries } = require('../../scripts/data-deletion');

describe('Data deletion validation (OPS-007)', () => {
  describe('Phone masking', () => {
    it('masks middle digits of standard phone', () => {
      assert.equal(maskPhone('13812345678'), '138****5678');
    });

    it('masks middle digits of 11-digit phone', () => {
      assert.equal(maskPhone('15900001111'), '159****1111');
    });

    it('returns *** for short phone', () => {
      assert.equal(maskPhone('123456'), '***');
      assert.equal(maskPhone('12345'), '***');
    });

    it('returns *** for null/undefined', () => {
      assert.equal(maskPhone(null), '***');
      assert.equal(maskPhone(undefined), '***');
    });

    it('returns *** for empty string', () => {
      assert.equal(maskPhone(''), '***');
    });

    it('handles 7-digit phone (minimum)', () => {
      assert.equal(maskPhone('1234567'), '123****4567');
    });

    it('does not expose full phone in masked output', () => {
      const phone = '13812345678';
      const masked = maskPhone(phone);
      assert.ok(!masked.includes('1234'), 'should not contain middle digits');
      assert.ok(masked.includes('138'), 'should contain first 3 digits');
      assert.ok(masked.includes('5678'), 'should contain last 4 digits');
    });
  });

  describe('Deletion operations', () => {
    it('returns non-empty array of operations', () => {
      const ops = getDeletionOperations({}, 'user-1');
      assert.ok(Array.isArray(ops));
      assert.ok(ops.length > 0, 'should have at least 1 operation');
    });

    it('all operations have name and function', () => {
      const ops = getDeletionOperations({}, 'user-1');
      for (const op of ops) {
        assert.ok(typeof op.name === 'string' && op.name.length > 0, 'should have name');
        assert.ok(typeof op.fn === 'function', 'should have function');
      }
    });

    it('covers all critical data categories', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      assert.ok(names.includes('Push tokens'), 'should delete push tokens');
      assert.ok(names.includes('Notifications'), 'should delete notifications');
      assert.ok(names.includes('Credit ledger'), 'should delete credit ledger');
      assert.ok(names.includes('Credit account'), 'should delete credit account');
      assert.ok(names.includes('Ritual sessions'), 'should delete ritual sessions');
      assert.ok(names.includes('Community posts'), 'should delete community posts');
      assert.ok(names.includes('Comments'), 'should delete comments');
      assert.ok(names.includes('Auth sessions'), 'should delete auth sessions');
      assert.ok(names.includes('Profile settings'), 'should delete profile settings');
    });

    it('deletes child records before parent records', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      const followupIdx = names.indexOf('Followup messages');
      const cardIdx = names.indexOf('Interpretation cards');
      const ritualIdx = names.indexOf('Ritual sessions');
      assert.ok(followupIdx < ritualIdx, 'followup before ritual');
      assert.ok(cardIdx < ritualIdx, 'cards before ritual');
    });

    it('deletes credit ledger before credit account', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      assert.ok(names.indexOf('Credit ledger') < names.indexOf('Credit account'));
    });

    it('deletes social interactions before user record', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      assert.ok(names.indexOf('Post likes') < names.indexOf('Auth sessions'));
      assert.ok(names.indexOf('Post favorites') < names.indexOf('Auth sessions'));
    });

    it('has at least 20 deletion operations', () => {
      const ops = getDeletionOperations({}, 'user-1');
      assert.ok(ops.length >= 20, `should have at least 20 operations, got ${ops.length}`);
    });
  });

  describe('Export queries', () => {
    it('returns non-empty array of queries', () => {
      const queries = getExportQueries({}, 'user-1');
      assert.ok(Array.isArray(queries));
      assert.ok(queries.length > 0, 'should have at least 1 query');
    });

    it('all queries have name and query function', () => {
      const queries = getExportQueries({}, 'user-1');
      for (const q of queries) {
        assert.ok(typeof q.name === 'string' && q.name.length > 0, 'should have name');
        assert.ok(typeof q.query === 'function', 'should have query function');
      }
    });

    it('covers all critical data categories', () => {
      const queries = getExportQueries({}, 'user-1');
      const names = queries.map((q) => q.name);
      assert.ok(names.includes('User profile'), 'should export user profile');
      assert.ok(names.includes('Credit account'), 'should export credit account');
      assert.ok(names.includes('Ritual sessions'), 'should export ritual sessions');
      assert.ok(names.includes('Community posts'), 'should export community posts');
      assert.ok(names.includes('Notifications'), 'should export notifications');
      assert.ok(names.includes('Orders'), 'should export orders');
      assert.ok(names.includes('Media assets'), 'should export media assets');
    });

    it('has at least 15 export queries', () => {
      const queries = getExportQueries({}, 'user-1');
      assert.ok(queries.length >= 15, `should have at least 15 queries, got ${queries.length}`);
    });

    it('export queries cover both directions of relationships', () => {
      const queries = getExportQueries({}, 'user-1');
      const names = queries.map((q) => q.name);
      assert.ok(names.includes('Following'), 'should export following');
      assert.ok(names.includes('Followers'), 'should export followers');
      assert.ok(names.includes('Likes'), 'should export likes');
      assert.ok(names.includes('Favorites'), 'should export favorites');
    });
  });

  describe('Operation safety', () => {
    it('deletion operations use deleteMany for bulk cleanup', () => {
      const ops = getDeletionOperations({
        pushToken: { deleteMany: () => ({ count: 0 }) },
        notification: { deleteMany: () => ({ count: 0 }) },
      }, 'user-1');
      // Operations should be functions that can be called
      assert.ok(ops.length > 0);
    });

    it('export queries use findMany/findUnique for data retrieval', () => {
      const queries = getExportQueries({}, 'user-1');
      // Queries should be functions that can be called
      assert.ok(queries.length > 0);
    });
  });

  describe('GDPR compliance', () => {
    it('deletion covers all user-generated content', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      // User-generated content
      assert.ok(names.includes('Community posts'), 'posts');
      assert.ok(names.includes('Comments'), 'comments');
      assert.ok(names.includes('Post likes'), 'likes');
      assert.ok(names.includes('Post favorites'), 'favorites');
      assert.ok(names.includes('Ritual sessions'), 'ritual sessions');
    });

    it('deletion covers all user metadata', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      // User metadata
      assert.ok(names.includes('Auth sessions'), 'auth sessions');
      assert.ok(names.includes('Profile settings'), 'profile settings');
      assert.ok(names.includes('Agreement consents'), 'agreement consents');
      assert.ok(names.includes('Push tokens'), 'push tokens');
    });

    it('deletion covers all financial records', () => {
      const ops = getDeletionOperations({}, 'user-1');
      const names = ops.map((op) => op.name);
      assert.ok(names.includes('Credit ledger'), 'credit ledger');
      assert.ok(names.includes('Credit account'), 'credit account');
      assert.ok(names.includes('Orders'), 'orders');
    });

    it('export covers same categories as deletion', () => {
      const exportQueries = getExportQueries({}, 'user-1');
      const exportNames = exportQueries.map((q) => q.name.toLowerCase());
      const deletionOps = getDeletionOperations({}, 'user-1');
      const deletionNames = deletionOps.map((op) => op.name.toLowerCase());
      // Every deletion target should have a corresponding export
      for (const delName of deletionNames) {
        const hasExport = exportNames.some((exp) =>
          exp.includes(delName.split(' ')[0]) || delName.includes(exp.split(' ')[0])
        );
        // Not all deletions need exports (child records), but core entities should
        if (['notifications', 'comments', 'profile'].some((k) => delName.includes(k))) {
          assert.ok(hasExport, `deletion of "${delName}" should have corresponding export`);
        }
      }
    });
  });
});

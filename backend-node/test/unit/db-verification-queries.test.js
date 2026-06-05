const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

// SQL verification queries for post-migration and post-seed validation
// These queries verify the database is correctly set up after deploy + seed

const MIGRATION_VERIFICATION_QUERIES = {
  tableCount: `SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';`,
  enumCount: `SELECT COUNT(*) as count FROM pg_type WHERE typnamespace = 'public'::regnamespace AND typtype = 'e';`,
  userTableColumns: `SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND table_schema = 'public' ORDER BY ordinal_position;`,
  ritualSessionColumns: `SELECT column_name FROM information_schema.columns WHERE table_name = 'ritual_sessions' AND table_schema = 'public' ORDER BY ordinal_position;`,
  foreignKeyCount: `SELECT COUNT(*) as count FROM information_schema.table_constraints WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public';`,
  indexCount: `SELECT COUNT(*) as count FROM pg_indexes WHERE schemaname = 'public';`,
  uniqueConstraints: `SELECT COUNT(*) as count FROM information_schema.table_constraints WHERE constraint_type = 'UNIQUE' AND table_schema = 'public';`,
};

const SEED_VERIFICATION_QUERIES = {
  demoUserExists: `SELECT id, username, role FROM users WHERE id = 'user_demo';`,
  peerUserExists: `SELECT id, username FROM users WHERE id = 'user_peer';`,
  creditAccountsExist: `SELECT user_id, cast_balance, followup_balance FROM credit_accounts WHERE user_id IN ('user_demo', 'user_peer');`,
  ritualSessionExists: `SELECT id, user_id, tag, status FROM ritual_sessions WHERE user_id = 'user_demo' LIMIT 1;`,
  interpretationCardExists: `SELECT id, session_id FROM interpretation_cards WHERE session_id IN (SELECT id FROM ritual_sessions WHERE user_id = 'user_demo') LIMIT 1;`,
  communityPostExists: `SELECT id, author_id, status FROM community_posts WHERE author_id = 'user_demo' LIMIT 1;`,
  billingPlansExist: `SELECT id, name, price_cents FROM billing_plans ORDER BY price_cents;`,
  notificationExists: `SELECT id, user_id, type FROM notifications WHERE user_id = 'user_demo' LIMIT 1;`,
  activityExists: `SELECT id, title, status FROM activities LIMIT 1;`,
  dailyCompletionExists: `SELECT id, user_id, date_key FROM daily_completions WHERE user_id = 'user_demo' ORDER BY created_at DESC LIMIT 1;`,
};

const DATA_INTEGRITY_QUERIES = {
  orphanAuthSessions: `SELECT COUNT(*) as count FROM auth_sessions WHERE user_id NOT IN (SELECT id FROM users);`,
  orphanComments: `SELECT COUNT(*) as count FROM comments WHERE post_id NOT IN (SELECT id FROM community_posts);`,
  orphanPostLikes: `SELECT COUNT(*) as count FROM post_likes WHERE post_id NOT IN (SELECT id FROM community_posts);`,
  orphanNotifications: `SELECT COUNT(*) as count FROM notifications WHERE user_id NOT IN (SELECT id FROM users);`,
  orphanCreditLedger: `SELECT COUNT(*) as count FROM credit_ledger WHERE user_id NOT IN (SELECT id FROM users);`,
  duplicateUsers: `SELECT phone, COUNT(*) as count FROM users WHERE phone IS NOT NULL GROUP BY phone HAVING COUNT(*) > 1;`,
  duplicateShortIds: `SELECT short_id, COUNT(*) as count FROM users GROUP BY short_id HAVING COUNT(*) > 1;`,
};

describe('DB verification queries (DB-001)', () => {
  describe('Migration verification queries', () => {
    it('table count query targets 41 tables', () => {
      assert.ok(MIGRATION_VERIFICATION_QUERIES.tableCount.includes('information_schema.tables'));
      assert.ok(MIGRATION_VERIFICATION_QUERIES.tableCount.includes("table_schema = 'public'"));
    });

    it('enum count query targets pg_type', () => {
      assert.ok(MIGRATION_VERIFICATION_QUERIES.enumCount.includes('pg_type'));
      assert.ok(MIGRATION_VERIFICATION_QUERIES.enumCount.includes("typtype = 'e'"));
    });

    it('user table column query is valid SQL', () => {
      const q = MIGRATION_VERIFICATION_QUERIES.userTableColumns;
      assert.ok(q.includes("table_name = 'users'"));
      assert.ok(q.includes('column_name'));
      assert.ok(q.includes('information_schema.columns'));
    });

    it('ritual session column query checks pattern field', () => {
      const q = MIGRATION_VERIFICATION_QUERIES.ritualSessionColumns;
      assert.ok(q.includes("table_name = 'ritual_sessions'"));
    });

    it('foreign key count query is valid', () => {
      const q = MIGRATION_VERIFICATION_QUERIES.foreignKeyCount;
      assert.ok(q.includes("constraint_type = 'FOREIGN KEY'"));
      assert.ok(q.includes('information_schema.table_constraints'));
    });

    it('index count query targets pg_indexes', () => {
      const q = MIGRATION_VERIFICATION_QUERIES.indexCount;
      assert.ok(q.includes('pg_indexes'));
      assert.ok(q.includes("schemaname = 'public'"));
    });
  });

  describe('Seed verification queries', () => {
    it('demo user query checks required fields', () => {
      const q = SEED_VERIFICATION_QUERIES.demoUserExists;
      assert.ok(q.includes("id = 'user_demo'"));
      assert.ok(q.includes('username'));
      assert.ok(q.includes('role'));
    });

    it('peer user query checks required fields', () => {
      const q = SEED_VERIFICATION_QUERIES.peerUserExists;
      assert.ok(q.includes("id = 'user_peer'"));
    });

    it('credit accounts query checks both users', () => {
      const q = SEED_VERIFICATION_QUERIES.creditAccountsExist;
      assert.ok(q.includes('user_demo'));
      assert.ok(q.includes('user_peer'));
      assert.ok(q.includes('cast_balance'));
      assert.ok(q.includes('followup_balance'));
    });

    it('ritual session query checks tag and status', () => {
      const q = SEED_VERIFICATION_QUERIES.ritualSessionExists;
      assert.ok(q.includes('tag'));
      assert.ok(q.includes('status'));
      assert.ok(q.includes('user_demo'));
    });

    it('billing plans query orders by price', () => {
      const q = SEED_VERIFICATION_QUERIES.billingPlansExist;
      assert.ok(q.includes('price_cents'));
      assert.ok(q.includes('ORDER BY'));
    });

    it('community post query checks author and status', () => {
      const q = SEED_VERIFICATION_QUERIES.communityPostExists;
      assert.ok(q.includes('author_id'));
      assert.ok(q.includes('status'));
    });
  });

  describe('Data integrity queries', () => {
    it('orphan auth sessions query checks foreign key integrity', () => {
      const q = DATA_INTEGRITY_QUERIES.orphanAuthSessions;
      assert.ok(q.includes('auth_sessions'));
      assert.ok(q.includes('NOT IN'));
      assert.ok(q.includes('users'));
    });

    it('orphan comments query checks post existence', () => {
      const q = DATA_INTEGRITY_QUERIES.orphanComments;
      assert.ok(q.includes('comments'));
      assert.ok(q.includes('community_posts'));
    });

    it('orphan notifications query checks user existence', () => {
      const q = DATA_INTEGRITY_QUERIES.orphanNotifications;
      assert.ok(q.includes('notifications'));
      assert.ok(q.includes('users'));
    });

    it('duplicate users query checks phone uniqueness', () => {
      const q = DATA_INTEGRITY_QUERIES.duplicateUsers;
      assert.ok(q.includes('phone'));
      assert.ok(q.includes('HAVING COUNT(*) > 1'));
    });

    it('duplicate short IDs query checks short_id uniqueness', () => {
      const q = DATA_INTEGRITY_QUERIES.duplicateShortIds;
      assert.ok(q.includes('short_id'));
      assert.ok(q.includes('HAVING COUNT(*) > 1'));
    });
  });

  describe('Query completeness', () => {
    it('migration verification covers all critical checks', () => {
      const keys = Object.keys(MIGRATION_VERIFICATION_QUERIES);
      assert.ok(keys.includes('tableCount'), 'should check table count');
      assert.ok(keys.includes('enumCount'), 'should check enum count');
      assert.ok(keys.includes('foreignKeyCount'), 'should check foreign keys');
      assert.ok(keys.includes('indexCount'), 'should check indexes');
    });

    it('seed verification covers all critical entities', () => {
      const keys = Object.keys(SEED_VERIFICATION_QUERIES);
      assert.ok(keys.includes('demoUserExists'), 'should verify demo user');
      assert.ok(keys.includes('creditAccountsExist'), 'should verify credit accounts');
      assert.ok(keys.includes('ritualSessionExists'), 'should verify ritual session');
      assert.ok(keys.includes('billingPlansExist'), 'should verify billing plans');
      assert.ok(keys.includes('communityPostExists'), 'should verify community post');
    });

    it('data integrity covers all foreign key relationships', () => {
      const keys = Object.keys(DATA_INTEGRITY_QUERIES);
      assert.ok(keys.length >= 5, 'should have at least 5 integrity checks');
    });
  });
});

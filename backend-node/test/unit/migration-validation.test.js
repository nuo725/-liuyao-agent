const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const migrationDir = path.join(__dirname, '..', '..', 'prisma', 'migrations');
const migration1Path = path.join(migrationDir, '202606050001_initial_schema', 'migration.sql');
const migration2Path = path.join(migrationDir, '202606050002_rate_limit_buckets', 'migration.sql');
const migration1 = fs.readFileSync(migration1Path, 'utf8');
const migration2 = fs.readFileSync(migration2Path, 'utf8');
const migration = migration1 + '\n' + migration2;

function extractTables(sql) {
  const tables = [];
  const regex = /CREATE TABLE "(\w+)" \(([\s\S]*?)\n\);/g;
  let match;
  while ((match = regex.exec(sql)) !== null) {
    const name = match[1];
    const body = match[2];
    const columns = body
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith('CONSTRAINT'))
      .map((line) => {
        const parts = line.match(/"(\w+)"\s+(\S+)/);
        return parts ? { name: parts[1], type: parts[2] } : null;
      })
      .filter(Boolean);
    tables.push({ name, columns });
  }
  return tables;
}

function extractEnums(sql) {
  const enums = [];
  const regex = /CREATE TYPE "(\w+)" AS ENUM \(([^)]+)\);/g;
  let match;
  while ((match = regex.exec(sql)) !== null) {
    const name = match[1];
    const values = match[2].split(',').map((v) => v.trim().replace(/'/g, ''));
    enums.push({ name, values });
  }
  return enums;
}

function extractForeignKeys(sql) {
  const fks = [];
  const regex = /ALTER TABLE "(\w+)" ADD CONSTRAINT "\w+" FOREIGN KEY \("(\w+)"\) REFERENCES "(\w+)"\("(\w+)"\)/g;
  let match;
  while ((match = regex.exec(sql)) !== null) {
    fks.push({ table: match[1], column: match[2], refTable: match[3], refColumn: match[4] });
  }
  return fks;
}

function extractIndexes(sql) {
  const indexes = [];
  const regex = /CREATE (UNIQUE )?INDEX "(\w+)" ON "(\w+)"\(([^)]+)\);/g;
  let match;
  while ((match = regex.exec(sql)) !== null) {
    indexes.push({ unique: Boolean(match[1]), name: match[2], table: match[3], columns: match[4] });
  }
  return indexes;
}

const tables = extractTables(migration);
const enums = extractEnums(migration);
const foreignKeys = extractForeignKeys(migration);
const indexes = extractIndexes(migration);
const tableNames = tables.map((t) => t.name);

describe('Migration SQL validation (DB-001)', () => {
  describe('Table coverage', () => {
    it('creates all expected 41 tables matching Prisma schema', () => {
      const expected = [
        'users', 'auth_sessions', 'social_accounts', 'agreement_consents', 'profile_settings',
        'ritual_sessions', 'interpretation_cards', 'followup_messages', 'emotion_calibrations',
        'safety_assessments', 'community_posts', 'post_views', 'post_hides', 'comments',
        'post_likes', 'post_favorites', 'post_reports', 'user_follows', 'user_blocks',
        'moderation_records', 'same_frequency_unlocks', 'activities', 'activity_joins',
        'notifications', 'push_tokens', 'credit_accounts', 'credit_ledger',
        'billing_plans', 'billing_orders', 'share_card_drafts', 'media_assets',
        'support_tickets', 'checkin_records', 'daily_completions', 'analytics_events',
        'weekly_metrics', 'idempotency_keys', 'outbox_jobs', 'anonymous_profiles',
        'ritual_feedbacks', 'rate_limit_buckets',
      ];

      for (const name of expected) {
        assert.ok(tableNames.includes(name), `Missing table: ${name}`);
      }
    });

    it('users table has identity columns', () => {
      const users = tables.find((t) => t.name === 'users');
      assert.ok(users);
      const colNames = users.columns.map((c) => c.name);
      assert.ok(colNames.includes('id'));
      assert.ok(colNames.includes('phone'));
      assert.ok(colNames.includes('username'));
      assert.ok(colNames.includes('role'));
      assert.ok(colNames.includes('status'));
      assert.ok(colNames.includes('short_id'));
    });

    it('ritual_sessions table has hexagram columns', () => {
      const sessions = tables.find((t) => t.name === 'ritual_sessions');
      assert.ok(sessions);
      const colNames = sessions.columns.map((c) => c.name);
      assert.ok(colNames.includes('question'));
      assert.ok(colNames.includes('tag'));
      assert.ok(colNames.includes('pattern'));
      assert.ok(colNames.includes('status'));
      assert.ok(colNames.includes('risk_level'));
    });

    it('community_posts table has content and metrics columns', () => {
      const posts = tables.find((t) => t.name === 'community_posts');
      assert.ok(posts);
      const colNames = posts.columns.map((c) => c.name);
      assert.ok(colNames.includes('author_id'));
      assert.ok(colNames.includes('share_text'));
      assert.ok(colNames.includes('metrics'));
      assert.ok(colNames.includes('status'));
    });

    it('credit_accounts table has balance columns', () => {
      const accounts = tables.find((t) => t.name === 'credit_accounts');
      assert.ok(accounts);
      const colNames = accounts.columns.map((c) => c.name);
      assert.ok(colNames.includes('user_id'));
      assert.ok(colNames.includes('cast_balance'));
      assert.ok(colNames.includes('followup_balance'));
      assert.ok(colNames.includes('is_vip'));
      assert.ok(colNames.includes('vip_expires_at'));
    });

    it('outbox_jobs table has job processing columns', () => {
      const jobs = tables.find((t) => t.name === 'outbox_jobs');
      assert.ok(jobs);
      const colNames = jobs.columns.map((c) => c.name);
      assert.ok(colNames.includes('type'));
      assert.ok(colNames.includes('payload'));
      assert.ok(colNames.includes('status'));
      assert.ok(colNames.includes('attempts'));
      assert.ok(colNames.includes('max_attempts'));
      assert.ok(colNames.includes('locked_at'));
    });

    it('rate_limit_buckets table has rate limiting columns', () => {
      const bucket = tables.find((t) => t.name === 'rate_limit_buckets');
      assert.ok(bucket);
      const colNames = bucket.columns.map((c) => c.name);
      assert.ok(colNames.includes('identifier'));
      assert.ok(colNames.includes('action'));
      assert.ok(colNames.includes('count'));
      assert.ok(colNames.includes('expires_at'));
    });
  });

  describe('Enum coverage', () => {
    it('creates all expected enums', () => {
      const enumNames = enums.map((e) => e.name);
      const expected = [
        'UserStatus', 'UserRole', 'Gender', 'SessionStatus', 'HexagramLine',
        'QuestionTag', 'RiskLevel', 'MessageType', 'PostStatus', 'CommentStatus',
        'ReportReason', 'ReportStatus', 'ModerationDecision', 'NotificationType',
        'ActivityStatus', 'JoinStatus', 'OrderStatus', 'LedgerType',
        'MediaPurpose', 'MediaStatus', 'TicketCategory', 'TicketStatus',
        'Platform', 'JobStatus',
      ];
      for (const name of expected) {
        assert.ok(enumNames.includes(name), `Missing enum: ${name}`);
      }
    });

    it('UserStatus has correct values', () => {
      const userStatus = enums.find((e) => e.name === 'UserStatus');
      assert.deepEqual(userStatus.values, ['active', 'deleted']);
    });

    it('QuestionTag covers divination categories', () => {
      const tag = enums.find((e) => e.name === 'QuestionTag');
      assert.ok(tag.values.includes('relationship'));
      assert.ok(tag.values.includes('career'));
      assert.ok(tag.values.includes('emotion'));
      assert.ok(tag.values.includes('choice'));
    });

    it('OrderStatus covers payment lifecycle', () => {
      const status = enums.find((e) => e.name === 'OrderStatus');
      assert.ok(status.values.includes('created'));
      assert.ok(status.values.includes('paying'));
      assert.ok(status.values.includes('paid'));
      assert.ok(status.values.includes('failed'));
      assert.ok(status.values.includes('refunded'));
    });
  });

  describe('Foreign key integrity', () => {
    it('auth_sessions references users', () => {
      const fk = foreignKeys.find((f) => f.table === 'auth_sessions' && f.column === 'user_id');
      assert.ok(fk);
      assert.equal(fk.refTable, 'users');
      assert.equal(fk.refColumn, 'id');
    });

    it('community_posts references users via author_id', () => {
      const fk = foreignKeys.find((f) => f.table === 'community_posts' && f.column === 'author_id');
      assert.ok(fk);
      assert.equal(fk.refTable, 'users');
    });

    it('community_posts references interpretation_cards via card_id', () => {
      const fk = foreignKeys.find((f) => f.table === 'community_posts' && f.column === 'card_id');
      assert.ok(fk);
      assert.equal(fk.refTable, 'interpretation_cards');
    });

    it('comments reference community_posts', () => {
      const fk = foreignKeys.find((f) => f.table === 'comments' && f.column === 'post_id');
      assert.ok(fk);
      assert.equal(fk.refTable, 'community_posts');
    });

    it('interpretation_cards references ritual_sessions', () => {
      const fk = foreignKeys.find((f) => f.table === 'interpretation_cards' && f.column === 'session_id');
      assert.ok(fk);
      assert.equal(fk.refTable, 'ritual_sessions');
    });

    it('billing_orders references billing_plans', () => {
      const fk = foreignKeys.find((f) => f.table === 'billing_orders' && f.column === 'plan_id');
      assert.ok(fk);
      assert.equal(fk.refTable, 'billing_plans');
    });

    it('all foreign keys use CASCADE on delete for user references', () => {
      const userFks = foreignKeys.filter((f) => f.refTable === 'users');
      assert.ok(userFks.length >= 15, `Expected at least 15 user foreign keys, got ${userFks.length}`);
      // Verify the SQL contains CASCADE for these
      for (const fk of userFks) {
        const pattern = new RegExp(`ALTER TABLE "${fk.table}" ADD CONSTRAINT.*REFERENCES "users".*CASCADE`);
        assert.ok(pattern.test(migration), `${fk.table}.${fk.column} should CASCADE on delete`);
      }
    });
  });

  describe('Index coverage', () => {
    it('creates unique indexes for natural keys', () => {
      const uniqueIndexes = indexes.filter((i) => i.unique);
      const indexNames = uniqueIndexes.map((i) => i.name);
      assert.ok(indexNames.includes('users_phone_key'), 'users.phone should be unique');
      assert.ok(indexNames.includes('users_short_id_key'), 'users.short_id should be unique');
      assert.ok(indexNames.includes('profile_settings_user_id_key'), 'profile_settings.user_id should be unique');
      assert.ok(indexNames.includes('credit_accounts_user_id_key'), 'credit_accounts.user_id should be unique');
      assert.ok(indexNames.includes('push_tokens_token_key'), 'push_tokens.token should be unique');
    });

    it('creates indexes for common query patterns', () => {
      const indexNames = indexes.map((i) => i.name);
      assert.ok(indexNames.includes('ritual_sessions_user_id_created_at_idx'));
      assert.ok(indexNames.includes('community_posts_status_created_at_idx'));
      assert.ok(indexNames.includes('notifications_user_id_created_at_idx'));
      assert.ok(indexNames.includes('credit_ledger_user_id_created_at_idx'));
      assert.ok(indexNames.includes('outbox_jobs_status_available_at_idx'));
    });

    it('creates composite unique indexes for idempotency', () => {
      const uniqueIndexes = indexes.filter((i) => i.unique);
      const hasIdempotencyKey = uniqueIndexes.some((i) => i.name.includes('idempotency_key'));
      assert.ok(hasIdempotencyKey, 'should have idempotency key unique index');
    });
  });

  describe('Schema consistency', () => {
    it('migration has exactly 41 CREATE TABLE statements across all migrations', () => {
      assert.equal(tables.length, 41, `Expected 41 tables, got ${tables.length}`);
    });

    it('migration has exactly 24 CREATE TYPE (enum) statements', () => {
      assert.equal(enums.length, 24, `Expected 24 enums, got ${enums.length}`);
    });

    it('all tables have primary key constraints', () => {
      for (const table of tables) {
        const hasPk = migration.includes(`"${table.name}_pkey" PRIMARY KEY`);
        assert.ok(hasPk, `Table ${table.name} should have a primary key`);
      }
    });

    it('all tables have created_at or equivalent timestamp column', () => {
      // Some tables use alternative timestamp columns or don't need created_at
      const exceptions = {
        agreement_consents: 'consented_at',
        same_frequency_unlocks: 'unlocked_at',
        profile_settings: null, // settings are created with user, no separate timestamp needed
      };
      for (const table of tables) {
        const expectedCol = exceptions[table.name];
        if (expectedCol === null) continue; // skip tables that don't need timestamps
        const col = expectedCol || 'created_at';
        const hasTimestamp = table.columns.some((c) => c.name === col);
        assert.ok(hasTimestamp, `Table ${table.name} should have ${col} column`);
      }
    });

    it('all foreign keys reference existing tables', () => {
      for (const fk of foreignKeys) {
        assert.ok(tableNames.includes(fk.refTable), `FK ${fk.table}.${fk.column} references non-existent table ${fk.refTable}`);
      }
    });
  });
});

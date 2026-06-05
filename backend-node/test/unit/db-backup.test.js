const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  redactDatabaseUrl,
  redactArgs,
  buildManifest,
  parseBackupArgs,
  runBackup,
} = require('../../scripts/db-backup');

describe('db-backup', () => {
  describe('redactDatabaseUrl', () => {
    it('redacts password from PostgreSQL URL', () => {
      const result = redactDatabaseUrl('postgresql://zhouyi:secretpass@localhost:5432/zhouyi');
      assert.ok(!result.includes('secretpass'));
      assert.ok(result.includes('zhouyi'));
      assert.ok(result.includes('localhost'));
    });

    it('handles URL without password', () => {
      const result = redactDatabaseUrl('postgresql://zhouyi@localhost:5432/zhouyi');
      assert.ok(result.includes('zhouyi'));
      assert.ok(result.includes('localhost'));
    });

    it('returns placeholder for invalid URL', () => {
      assert.equal(redactDatabaseUrl('not-a-url'), '<redacted-database-url>');
    });

    it('returns placeholder for empty string', () => {
      assert.equal(redactDatabaseUrl(''), '<redacted-database-url>');
    });
  });

  describe('redactArgs', () => {
    it('redacts the value after --dbname', () => {
      const result = redactArgs(['--dbname', 'postgresql://user:pass@host/db', '--format', 'custom']);
      assert.ok(!result[1].includes('pass'));
      assert.equal(result[2], '--format');
      assert.equal(result[3], 'custom');
    });

    it('does not redact other arguments', () => {
      const result = redactArgs(['--format', 'custom', '--no-owner']);
      assert.deepEqual(result, ['--format', 'custom', '--no-owner']);
    });
  });

  describe('parseBackupArgs', () => {
    it('parses --dry-run flag', () => {
      const result = parseBackupArgs(['--dry-run']);
      assert.equal(result.dryRun, true);
      assert.equal(result.outputDir, 'backups');
    });

    it('parses --out flag', () => {
      const result = parseBackupArgs(['--out=my-backups']);
      assert.equal(result.dryRun, false);
      assert.equal(result.outputDir, 'my-backups');
    });

    it('parses combined flags', () => {
      const result = parseBackupArgs(['--dry-run', '--out=custom-dir']);
      assert.equal(result.dryRun, true);
      assert.equal(result.outputDir, 'custom-dir');
    });

    it('defaults when no args', () => {
      const result = parseBackupArgs([]);
      assert.equal(result.dryRun, false);
      assert.equal(result.outputDir, 'backups');
    });
  });

  describe('buildManifest', () => {
    it('creates manifest with redacted URL', () => {
      const manifest = buildManifest({
        outputFile: '/tmp/backups/zhouyi-2026.dump',
        databaseUrl: 'postgresql://user:secret@localhost:5432/zhouyi',
      });

      assert.equal(manifest.file, 'zhouyi-2026.dump');
      assert.equal(manifest.format, 'pg_dump custom');
      assert.ok(manifest.createdAt);
      assert.ok(!manifest.databaseUrl.includes('secret'));
    });
  });

  describe('runBackup', () => {
    it('returns error when DATABASE_URL is missing', () => {
      const result = runBackup({ databaseUrl: undefined });
      assert.equal(result.ok, false);
      assert.match(result.error, /DATABASE_URL/);
    });

    it('returns dry-run info without spawning process', () => {
      const result = runBackup({
        databaseUrl: 'postgresql://user:pass@localhost:5432/zhouyi',
        dryRun: true,
        outputDir: 'test-backups',
      });

      assert.equal(result.ok, true);
      assert.equal(result.dryRun, true);
      assert.ok(result.outputFile.includes('zhouyi-'));
      assert.ok(result.command.includes('pg_dump'));
      assert.ok(!result.command.includes('pass'));
    });
  });
});

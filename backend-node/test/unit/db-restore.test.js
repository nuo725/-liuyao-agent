const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  redactDatabaseUrl,
  parseRestoreArgs,
  buildRestoreCommand,
  runRestore,
} = require('../../scripts/db-restore');

describe('db-restore', () => {
  describe('redactDatabaseUrl', () => {
    it('redacts password from PostgreSQL URL', () => {
      const result = redactDatabaseUrl('postgresql://zhouyi:secretpass@localhost:5432/zhouyi');
      assert.ok(!result.includes('secretpass'));
      assert.ok(result.includes('zhouyi'));
    });

    it('returns placeholder for invalid URL', () => {
      assert.equal(redactDatabaseUrl('bad'), '<redacted-database-url>');
    });
  });

  describe('parseRestoreArgs', () => {
    it('parses --file, --dry-run, and --clean flags', () => {
      const result = parseRestoreArgs(['--file=backups/test.dump', '--dry-run', '--clean']);
      assert.equal(result.file, 'backups/test.dump');
      assert.equal(result.dryRun, true);
      assert.equal(result.clean, true);
    });

    it('defaults when no args', () => {
      const result = parseRestoreArgs([]);
      assert.equal(result.file, null);
      assert.equal(result.dryRun, false);
      assert.equal(result.clean, false);
    });
  });

  describe('buildRestoreCommand', () => {
    it('uses pg_restore for .dump files', () => {
      const { command, commandArgs, isSql } = buildRestoreCommand({
        inputFile: '/tmp/backup.dump',
        databaseUrl: 'postgresql://user:pass@localhost/db',
        clean: false,
      });

      assert.ok(command.includes('pg_restore'));
      assert.equal(isSql, false);
      assert.ok(commandArgs.includes('--no-owner'));
      assert.ok(commandArgs.includes('--no-privileges'));
      assert.ok(!commandArgs.includes('--clean'));
    });

    it('uses psql for .sql files', () => {
      const { command, commandArgs, isSql } = buildRestoreCommand({
        inputFile: '/tmp/backup.sql',
        databaseUrl: 'postgresql://user:pass@localhost/db',
        clean: false,
      });

      assert.ok(command.includes('psql'));
      assert.equal(isSql, true);
      assert.ok(commandArgs.includes('--file'));
    });

    it('adds --clean and --if-exists when clean=true for dump files', () => {
      const { commandArgs } = buildRestoreCommand({
        inputFile: '/tmp/backup.dump',
        databaseUrl: 'postgresql://user:pass@localhost/db',
        clean: true,
      });

      assert.ok(commandArgs.includes('--clean'));
      assert.ok(commandArgs.includes('--if-exists'));
    });
  });

  describe('runRestore', () => {
    it('returns error when DATABASE_URL is missing', () => {
      const result = runRestore({ file: 'test.dump', databaseUrl: undefined });
      assert.equal(result.ok, false);
      assert.match(result.error, /DATABASE_URL/);
    });

    it('returns error when file is not provided', () => {
      const result = runRestore({ databaseUrl: 'postgresql://user:pass@localhost/db' });
      assert.equal(result.ok, false);
      assert.match(result.error, /Usage/);
    });

    it('returns dry-run info without spawning process', () => {
      const result = runRestore({
        file: 'backups/test.dump',
        databaseUrl: 'postgresql://user:pass@localhost:5432/zhouyi',
        dryRun: true,
      });

      assert.equal(result.ok, true);
      assert.equal(result.dryRun, true);
      assert.ok(result.inputFile.includes('test.dump'));
      assert.ok(result.command.includes('pg_restore'));
      assert.ok(!result.command.includes('pass'));
    });

    it('detects SQL format in dry-run', () => {
      const result = runRestore({
        file: 'backups/backup.sql',
        databaseUrl: 'postgresql://user:pass@localhost:5432/zhouyi',
        dryRun: true,
      });

      assert.equal(result.ok, true);
      assert.ok(result.command.includes('psql'));
    });
  });
});

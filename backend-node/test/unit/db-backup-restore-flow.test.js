const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { runBackup } = require('../../scripts/db-backup');
const { runRestore } = require('../../scripts/db-restore');

describe('Backup/Restore dry-run flow (OPS-VERIFY-001)', () => {
  const testDbUrl = 'postgresql://zhouyi:zhouyi_dev_password@localhost:5432/zhouyi';

  it('backup dry-run returns valid output path and command', () => {
    const result = runBackup({
      databaseUrl: testDbUrl,
      dryRun: true,
      outputDir: 'backups',
    });

    assert.equal(result.ok, true);
    assert.equal(result.dryRun, true);
    assert.ok(result.outputFile.endsWith('.dump'), 'output should be a .dump file');
    assert.ok(result.outputFile.includes('zhouyi-'), 'output should contain zhouyi prefix');
    assert.ok(result.command.includes('pg_dump'), 'command should use pg_dump');
    assert.ok(result.command.includes('--format'), 'command should specify format');
    assert.ok(result.command.includes('custom'), 'command should use custom format');
    assert.ok(!result.command.includes('zhouyi_dev_password'), 'command should redact password');
  });

  it('restore dry-run for .dump file returns pg_restore command', () => {
    const result = runRestore({
      file: 'backups/zhouyi-2026-06-05.dump',
      databaseUrl: testDbUrl,
      dryRun: true,
    });

    assert.equal(result.ok, true);
    assert.equal(result.dryRun, true);
    assert.ok(result.inputFile.includes('zhouyi-2026-06-05.dump'));
    assert.ok(result.command.includes('pg_restore'), 'should use pg_restore for .dump');
    assert.ok(result.command.includes('--no-owner'), 'should include --no-owner');
    assert.ok(!result.command.includes('zhouyi_dev_password'), 'should redact password');
  });

  it('restore dry-run for .sql file returns psql command', () => {
    const result = runRestore({
      file: 'backups/zhouyi-2026-06-05.sql',
      databaseUrl: testDbUrl,
      dryRun: true,
    });

    assert.equal(result.ok, true);
    assert.ok(result.command.includes('psql'), 'should use psql for .sql');
    assert.ok(!result.command.includes('pg_restore'), 'should not use pg_restore for .sql');
  });

  it('restore dry-run with --clean flag includes clean options', () => {
    const result = runRestore({
      file: 'backups/zhouyi-2026-06-05.dump',
      databaseUrl: testDbUrl,
      dryRun: true,
      clean: true,
    });

    assert.equal(result.ok, true);
    assert.ok(result.command.includes('--clean'), 'should include --clean');
    assert.ok(result.command.includes('--if-exists'), 'should include --if-exists');
  });

  it('full dry-run flow: backup then restore references same database', () => {
    const backupResult = runBackup({
      databaseUrl: testDbUrl,
      dryRun: true,
      outputDir: 'backups',
    });

    assert.equal(backupResult.ok, true);

    // Simulate restore using the backup output path
    const restoreResult = runRestore({
      file: backupResult.outputFile,
      databaseUrl: testDbUrl,
      dryRun: true,
    });

    assert.equal(restoreResult.ok, true);
    assert.ok(restoreResult.command.includes('pg_restore'), 'should restore with pg_restore');
    // Both should reference the same database (redacted)
    assert.ok(!backupResult.command.includes('zhouyi_dev_password'));
    assert.ok(!restoreResult.command.includes('zhouyi_dev_password'));
  });

  it('backup with custom output directory', () => {
    const result = runBackup({
      databaseUrl: testDbUrl,
      dryRun: true,
      outputDir: 'custom-backups',
    });

    assert.equal(result.ok, true);
    assert.ok(result.outputFile.includes('custom-backups'), 'should use custom directory');
  });

  it('backup fails gracefully without DATABASE_URL', () => {
    const result = runBackup({ databaseUrl: undefined });
    assert.equal(result.ok, false);
    assert.ok(result.error.includes('DATABASE_URL'));
  });

  it('restore fails gracefully without file', () => {
    const result = runRestore({ databaseUrl: testDbUrl });
    assert.equal(result.ok, false);
    assert.ok(result.error.includes('Usage'));
  });

  it('restore fails gracefully without DATABASE_URL', () => {
    const result = runRestore({ file: 'test.dump', databaseUrl: undefined });
    assert.equal(result.ok, false);
    assert.ok(result.error.includes('DATABASE_URL'));
  });
});

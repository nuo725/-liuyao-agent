const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { buildManifest, redactDatabaseUrl } = require('../../scripts/db-backup');

describe('Backup manifest validation (OPS-VERIFY-001)', () => {
  describe('Manifest structure', () => {
    it('creates manifest with required fields', () => {
      const manifest = buildManifest({
        outputFile: '/tmp/backups/zhouyi-2026-06-05.dump',
        databaseUrl: 'postgresql://zhouyi:secret@localhost:5432/zhouyi',
      });

      assert.ok(manifest.file, 'should have file field');
      assert.ok(manifest.createdAt, 'should have createdAt field');
      assert.ok(manifest.databaseUrl, 'should have databaseUrl field');
      assert.ok(manifest.format, 'should have format field');
    });

    it('uses pg_dump custom format', () => {
      const manifest = buildManifest({
        outputFile: '/tmp/backups/zhouyi-2026-06-05.dump',
        databaseUrl: 'postgresql://zhouyi:secret@localhost:5432/zhouyi',
      });

      assert.equal(manifest.format, 'pg_dump custom');
    });

    it('redacts password in manifest', () => {
      const manifest = buildManifest({
        outputFile: '/tmp/backups/zhouyi-2026-06-05.dump',
        databaseUrl: 'postgresql://zhouyi:supersecret@localhost:5432/zhouyi',
      });

      assert.ok(!manifest.databaseUrl.includes('supersecret'), 'should not contain password');
      assert.ok(manifest.databaseUrl.includes('zhouyi'), 'should contain username');
      assert.ok(manifest.databaseUrl.includes('localhost'), 'should contain host');
    });

    it('extracts filename from full path', () => {
      const manifest = buildManifest({
        outputFile: '/var/backups/zhouyi-2026-06-05T12-00-00.dump',
        databaseUrl: 'postgresql://zhouyi:secret@localhost:5432/zhouyi',
      });

      assert.equal(manifest.file, 'zhouyi-2026-06-05T12-00-00.dump');
    });

    it('has ISO timestamp format', () => {
      const manifest = buildManifest({
        outputFile: '/tmp/backups/test.dump',
        databaseUrl: 'postgresql://zhouyi:secret@localhost:5432/zhouyi',
      });

      assert.ok(manifest.createdAt.endsWith('Z'), 'should be UTC');
      assert.ok(!isNaN(Date.parse(manifest.createdAt)), 'should be valid date');
    });
  });

  describe('URL redaction', () => {
    it('redacts password from standard PostgreSQL URL', () => {
      const result = redactDatabaseUrl('postgresql://user:password123@host:5432/db');
      assert.ok(!result.includes('password123'));
      assert.ok(result.includes('user'));
      assert.ok(result.includes('host'));
      assert.ok(result.includes('db'));
    });

    it('redacts password from postgres:// URL', () => {
      const result = redactDatabaseUrl('postgres://admin:secret@db.example.com:5432/zhouyi');
      assert.ok(!result.includes('secret'));
      assert.ok(result.includes('admin'));
      assert.ok(result.includes('db.example.com'));
    });

    it('handles URL without password', () => {
      const result = redactDatabaseUrl('postgresql://user@localhost:5432/db');
      assert.ok(result.includes('user'));
      assert.ok(result.includes('localhost'));
    });

    it('handles URL with special characters in password', () => {
      const result = redactDatabaseUrl('postgresql://user:p@ss!w0rd@host/db');
      assert.ok(!result.includes('p@ss!w0rd'));
    });

    it('returns placeholder for invalid URL', () => {
      assert.equal(redactDatabaseUrl('not-a-url'), '<redacted-database-url>');
      assert.equal(redactDatabaseUrl(''), '<redacted-database-url>');
      assert.equal(redactDatabaseUrl(null), '<redacted-database-url>');
    });
  });

  describe('Manifest integrity', () => {
    it('manifest can be serialized to JSON', () => {
      const manifest = buildManifest({
        outputFile: '/tmp/backups/test.dump',
        databaseUrl: 'postgresql://zhouyi:secret@localhost:5432/zhouyi',
      });

      const json = JSON.stringify(manifest, null, 2);
      assert.ok(json.length > 0, 'should serialize to non-empty JSON');

      const parsed = JSON.parse(json);
      assert.equal(parsed.file, manifest.file);
      assert.equal(parsed.format, manifest.format);
    });

    it('manifest JSON is human-readable with indentation', () => {
      const manifest = buildManifest({
        outputFile: '/tmp/backups/test.dump',
        databaseUrl: 'postgresql://zhouyi:secret@localhost:5432/zhouyi',
      });

      const json = JSON.stringify(manifest, null, 2);
      assert.ok(json.includes('\n'), 'should have newlines');
      assert.ok(json.includes('  '), 'should have indentation');
    });

    it('manifest does not contain sensitive data after serialization', () => {
      const manifest = buildManifest({
        outputFile: '/tmp/backups/test.dump',
        databaseUrl: 'postgresql://zhouyi:mysecretpassword@localhost:5432/zhouyi',
      });

      const json = JSON.stringify(manifest);
      assert.ok(!json.includes('mysecretpassword'), 'JSON should not contain raw password');
    });
  });
});

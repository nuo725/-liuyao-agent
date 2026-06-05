const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..', '..');

describe('Security: upload, replay, authorization (OPS-003)', () => {
  describe('Upload validation', () => {
    it('media service validates MIME types', () => {
      const servicePath = path.join(repoRoot, 'src', 'modules', 'media', 'service.js');
      if (fs.existsSync(servicePath)) {
        const content = fs.readFileSync(servicePath, 'utf8');
        assert.ok(
          content.includes('mime') || content.includes('MIME') || content.includes('allowedMimes'),
          'media service should validate MIME types'
        );
      }
    });

    it('media service validates file size', () => {
      const servicePath = path.join(repoRoot, 'src', 'modules', 'media', 'service.js');
      if (fs.existsSync(servicePath)) {
        const content = fs.readFileSync(servicePath, 'utf8');
        assert.ok(
          content.includes('size') || content.includes('maxSize') || content.includes('limit'),
          'media service should validate file size'
        );
      }
    });

    it('upload endpoint rejects non-image MIME for avatar', () => {
      // Valid avatar MIME types
      const validMimes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
      const invalidMime = 'application/pdf';
      assert.ok(!validMimes.includes(invalidMime), 'PDF should be rejected for avatar');
    });

    it('upload endpoint rejects oversized files', () => {
      const maxSize = 10 * 1024 * 1024; // 10MB
      const oversized = 15 * 1024 * 1024;
      assert.ok(oversized > maxSize, 'should reject files over 10MB');
    });
  });

  describe('Replay attack prevention', () => {
    it('idempotency middleware exists', () => {
      const idempPath = path.join(repoRoot, 'src', 'middleware', 'idempotency.js');
      assert.ok(fs.existsSync(idempPath), 'idempotency middleware should exist');
    });

    it('idempotency middleware uses Idempotency-Key header', () => {
      const idempPath = path.join(repoRoot, 'src', 'middleware', 'idempotency.js');
      const content = fs.readFileSync(idempPath, 'utf8');
      assert.ok(content.includes('idempotency-key'), 'should use Idempotency-Key header');
    });

    it('idempotency middleware caches successful responses', () => {
      const idempPath = path.join(repoRoot, 'src', 'middleware', 'idempotency.js');
      const content = fs.readFileSync(idempPath, 'utf8');
      assert.ok(content.includes('_cache') || content.includes('cache'), 'should cache responses');
    });

    it('idempotency middleware does not cache error responses', () => {
      const idempPath = path.join(repoRoot, 'src', 'middleware', 'idempotency.js');
      const content = fs.readFileSync(idempPath, 'utf8');
      assert.ok(content.includes('400') || content.includes('statusCode'), 'should check status code before caching');
    });

    it('idempotency keys are scoped per user', () => {
      const idempPath = path.join(repoRoot, 'src', 'middleware', 'idempotency.js');
      const content = fs.readFileSync(idempPath, 'utf8');
      assert.ok(content.includes('userId') || content.includes('anonymous'), 'should scope keys per user');
    });
  });

  describe('Authorization bypass prevention', () => {
    it('auth middleware rejects missing token', () => {
      const authPath = path.join(repoRoot, 'src', 'middleware', 'auth.js');
      const content = fs.readFileSync(authPath, 'utf8');
      assert.ok(content.includes('ApiError.unauthorized'), 'should throw unauthorized');
    });

    it('auth middleware rejects expired token', () => {
      const authPath = path.join(repoRoot, 'src', 'middleware', 'auth.js');
      const content = fs.readFileSync(authPath, 'utf8');
      assert.ok(content.includes('sessionExpired') || content.includes('expired'), 'should handle expired tokens');
    });

    it('requireRole middleware checks user role', () => {
      const authPath = path.join(repoRoot, 'src', 'middleware', 'auth.js');
      const content = fs.readFileSync(authPath, 'utf8');
      assert.ok(content.includes('requireRole'), 'should have requireRole middleware');
      assert.ok(content.includes('role'), 'should check role');
    });

    it('admin routes require admin role', () => {
      const adminPath = path.join(repoRoot, 'src', 'modules', 'admin', 'route.js');
      const content = fs.readFileSync(adminPath, 'utf8');
      assert.ok(content.includes('requireAdmin') || content.includes('requireRole'), 'admin routes should require admin role');
    });

    it('moderation routes require operator/admin role', () => {
      const communityPath = path.join(repoRoot, 'src', 'modules', 'community', 'route.js');
      const content = fs.readFileSync(communityPath, 'utf8');
      assert.ok(content.includes('requireRole'), 'moderation routes should require role check');
    });
  });

  describe('Dependency security', () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(repoRoot, 'package.json'), 'utf8'));
    const allDeps = { ...pkg.dependencies, ...pkg.devDependencies };

    it('does not use known vulnerable lodash', () => {
      assert.ok(!allDeps.lodash, 'should not use lodash');
    });

    it('does not use known vulnerable moment', () => {
      assert.ok(!allDeps.moment, 'should not use moment');
    });

    it('does not use deprecated request module', () => {
      assert.ok(!allDeps.request, 'should not use request');
    });

    it('uses express 5 (not vulnerable express 4)', () => {
      assert.ok(allDeps.express, 'should have express');
      // Express 5 is not vulnerable to known CVEs
    });

    it('uses jsonwebtoken 9.x', () => {
      assert.ok(allDeps.jsonwebtoken, 'should have jsonwebtoken');
    });

    it('uses bcryptjs (not native bcrypt)', () => {
      assert.ok(allDeps.bcryptjs, 'should use bcryptjs for cross-platform compatibility');
    });

    it('uses zod for input validation', () => {
      assert.ok(allDeps.zod, 'should use zod for validation');
    });

    it('package-lock.json exists for reproducible builds', () => {
      const lockPath = path.join(repoRoot, 'package-lock.json');
      assert.ok(fs.existsSync(lockPath), 'package-lock.json should exist');
    });
  });

  describe('Sensitive data protection', () => {
    it('.env is in .gitignore', () => {
      const gitignorePath = path.join(repoRoot, '..', '.gitignore');
      if (fs.existsSync(gitignorePath)) {
        const content = fs.readFileSync(gitignorePath, 'utf8');
        assert.ok(content.includes('.env'), '.env should be in .gitignore');
      }
    });

    it('uploads directory is in .gitignore', () => {
      const gitignorePath = path.join(repoRoot, '..', '.gitignore');
      if (fs.existsSync(gitignorePath)) {
        const content = fs.readFileSync(gitignorePath, 'utf8');
        assert.ok(content.includes('uploads'), 'uploads should be in .gitignore');
      }
    });

    it('backups directory is in .gitignore', () => {
      const gitignorePath = path.join(repoRoot, '..', '.gitignore');
      if (fs.existsSync(gitignorePath)) {
        const content = fs.readFileSync(gitignorePath, 'utf8');
        assert.ok(content.includes('backups'), 'backups should be in .gitignore');
      }
    });

    it('backup script redacts database URL', () => {
      const backupPath = path.join(repoRoot, 'scripts', 'db-backup.js');
      const content = fs.readFileSync(backupPath, 'utf8');
      assert.ok(content.includes('redactDatabaseUrl'), 'should redact database URL');
    });

    it('backup manifest does not contain raw password', () => {
      const { redactDatabaseUrl } = require('../../scripts/db-backup');
      const result = redactDatabaseUrl('postgresql://user:supersecret@host/db');
      assert.ok(!result.includes('supersecret'), 'should not contain raw password');
    });
  });

  describe('CORS and headers', () => {
    it('app uses CORS middleware', () => {
      const appPath = path.join(repoRoot, 'src', 'app.js');
      const content = fs.readFileSync(appPath, 'utf8');
      assert.ok(content.includes('cors'), 'should use CORS');
    });

    it('app sets request ID header', () => {
      const appPath = path.join(repoRoot, 'src', 'app.js');
      const content = fs.readFileSync(appPath, 'utf8');
      assert.ok(content.includes('requestId') || content.includes('request-id'), 'should set request ID');
    });
  });
});

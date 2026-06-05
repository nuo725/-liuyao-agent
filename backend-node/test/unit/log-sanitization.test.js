const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..', '..');

describe('Log sanitization (OPS-007)', () => {
  describe('Logger redact configuration', () => {
    it('logger.js exists', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      assert.ok(fs.existsSync(loggerPath), 'logger.js should exist');
    });

    it('logger uses Pino with redact option', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('redact'), 'should have redact configuration');
    });

    it('redacts authorization header', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('authorization'), 'should redact authorization header');
    });

    it('redacts token fields', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('token'), 'should redact token fields');
    });

    it('redacts phone fields', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('phone'), 'should redact phone fields');
    });

    it('redacts password fields', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('password'), 'should redact password fields');
    });

    it('redacts question fields (privacy)', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('question'), 'should redact question fields');
    });

    it('redacts code fields (SMS verification)', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('code'), 'should redact code fields');
    });

    it('uses [REDACTED] as censor string', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('[REDACTED]'), 'should use [REDACTED] as censor');
    });
  });

  describe('Sensitive field coverage', () => {
    it('redact paths cover all sensitive request fields', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      // Check for wildcard redaction of sensitive fields
      assert.ok(content.includes('*.token'), 'should redact token in any nested object');
      assert.ok(content.includes('*.phone'), 'should redact phone in any nested object');
      assert.ok(content.includes('*.password'), 'should redact password in any nested object');
    });

    it('redact paths include request body fields', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('body.token'), 'should redact body.token');
      assert.ok(content.includes('body.phone'), 'should redact body.phone');
      assert.ok(content.includes('body.password'), 'should redact body.password');
      assert.ok(content.includes('body.question'), 'should redact body.question');
    });
  });

  describe('Data deletion script log safety', () => {
    it('data deletion script masks phone numbers', () => {
      const { maskPhone } = require('../../scripts/data-deletion');
      assert.equal(maskPhone('13812345678'), '138****5678');
      assert.equal(maskPhone(null), '***');
    });

    it('data deletion script does not log raw phone', () => {
      const scriptPath = path.join(repoRoot, 'scripts', 'data-deletion.js');
      const content = fs.readFileSync(scriptPath, 'utf8');
      // Script should use maskPhone before logging
      assert.ok(content.includes('maskPhone'), 'should use maskPhone for masking');
    });
  });

  describe('Backup script log safety', () => {
    it('backup script redacts database URL in output', () => {
      const { redactDatabaseUrl } = require('../../scripts/db-backup');
      const redacted = redactDatabaseUrl('postgresql://user:secretpass@host:5432/db');
      assert.ok(!redacted.includes('secretpass'), 'should not contain password');
      assert.ok(redacted.includes('user'), 'should contain username');
      assert.ok(redacted.includes('host'), 'should contain host');
    });

    it('backup manifest does not contain raw password', () => {
      const { buildManifest } = require('../../scripts/db-backup');
      const manifest = buildManifest({
        outputFile: '/tmp/test.dump',
        databaseUrl: 'postgresql://user:secretpass@host:5432/db',
      });
      const json = JSON.stringify(manifest);
      assert.ok(!json.includes('secretpass'), 'manifest should not contain password');
    });
  });

  describe('Error handler log safety', () => {
    it('error handler does not leak stack traces to client', () => {
      const handlerPath = path.join(repoRoot, 'src', 'middleware', 'error-handler.js');
      const content = fs.readFileSync(handlerPath, 'utf8');
      assert.ok(
        !content.includes('res.json({ stack') && !content.includes('err.stack'),
        'should not send stack traces to client'
      );
    });

    it('error handler logs errors internally', () => {
      const handlerPath = path.join(repoRoot, 'src', 'middleware', 'error-handler.js');
      const content = fs.readFileSync(handlerPath, 'utf8');
      assert.ok(content.includes('logger.error'), 'should log errors internally');
    });
  });

  describe('Auth service log safety', () => {
    it('auth service does not log raw tokens', () => {
      const authServicePath = path.join(repoRoot, 'src', 'modules', 'auth', 'service.js');
      if (fs.existsSync(authServicePath)) {
        const content = fs.readFileSync(authServicePath, 'utf8');
        // Should not log raw access tokens
        assert.ok(
          !content.includes('logger.info({ token:') && !content.includes('logger.debug({ token:'),
          'should not log raw tokens'
        );
      }
    });

    it('auth service does not log raw SMS codes', () => {
      const authServicePath = path.join(repoRoot, 'src', 'modules', 'auth', 'service.js');
      if (fs.existsSync(authServicePath)) {
        const content = fs.readFileSync(authServicePath, 'utf8');
        // Should not log raw verification codes in production
        assert.ok(
          !content.includes('logger.info({ code:') && !content.includes('logger.debug({ code:'),
          'should not log raw SMS codes'
        );
      }
    });
  });
});

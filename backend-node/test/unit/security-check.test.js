const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { runChecks, hasBlockingFailure } = require('../../scripts/security-check');

const gitignoreText = [
  '/backend-node/.env',
  '/backend-node/uploads/',
  '/backend-node/backups/',
].join('\n');

describe('Security check script', () => {
  it('passes a production-safe baseline', () => {
    const checks = runChecks({
      rootDir: process.cwd(),
      gitignoreText,
      env: {
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://zhouyi:password@localhost:5432/zhouyi',
        JWT_SECRET: 'prod-random-value-with-48-chars-abc123456789',
        SMS_PROVIDER: 'aliyun',
        PAYMENT_CALLBACK_SECRET: 'prod-callback-secret-value',
        RATE_LIMIT_STORE: 'database',
      },
    });

    assert.equal(hasBlockingFailure(checks), false);
  });

  it('blocks unsafe production settings', () => {
    const checks = runChecks({
      rootDir: process.cwd(),
      gitignoreText,
      env: {
        NODE_ENV: 'production',
        DATABASE_URL: 'sqlite://local.db',
        JWT_SECRET: 'change-me',
        SMS_PROVIDER: 'test',
        PAYMENT_CALLBACK_SECRET: 'dev_callback_secret',
        RATE_LIMIT_STORE: 'memory',
      },
    });

    assert.equal(hasBlockingFailure(checks), true);
  });
});

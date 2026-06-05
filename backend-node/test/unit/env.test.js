const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

// Set up test environment before requiring env module
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_SECRET = 'test_jwt_secret_for_env_validation_32_chars';
process.env.JWT_ACCESS_TTL = '7200';
process.env.JWT_REFRESH_TTL = '2592000';
process.env.PORT = '3000';
process.env.LOG_LEVEL = 'info';
process.env.RATE_LIMIT_STORE = 'memory';
process.env.SMS_PROVIDER = 'test';

const { getEnv } = require('../../src/config/env');

describe('Environment configuration', () => {
  describe('getEnv()', () => {
    it('returns parsed environment variables', () => {
      const env = getEnv();
      assert.ok(env, 'should return env object');
    });

    it('has PORT with default 3000', () => {
      const env = getEnv();
      assert.equal(typeof env.PORT, 'number');
      assert.ok(env.PORT > 0, 'PORT should be positive');
    });

    it('has NODE_ENV', () => {
      const env = getEnv();
      assert.ok(['development', 'test', 'production'].includes(env.NODE_ENV));
    });

    it('has LOG_LEVEL', () => {
      const env = getEnv();
      assert.ok(['trace', 'debug', 'info', 'warn', 'error', 'fatal'].includes(env.LOG_LEVEL));
    });

    it('has RATE_LIMIT_STORE', () => {
      const env = getEnv();
      assert.ok(['memory', 'database'].includes(env.RATE_LIMIT_STORE));
    });

    it('has DATABASE_URL as PostgreSQL string', () => {
      const env = getEnv();
      assert.ok(env.DATABASE_URL.startsWith('postgresql://') || env.DATABASE_URL.startsWith('postgres://'));
    });

    it('has JWT_SECRET with minimum length', () => {
      const env = getEnv();
      assert.ok(env.JWT_SECRET.length >= 32, 'JWT_SECRET should be at least 32 chars');
    });

    it('has JWT_ACCESS_TTL as number', () => {
      const env = getEnv();
      assert.equal(typeof env.JWT_ACCESS_TTL, 'number');
      assert.ok(env.JWT_ACCESS_TTL > 0);
    });

    it('has JWT_REFRESH_TTL as number', () => {
      const env = getEnv();
      assert.equal(typeof env.JWT_REFRESH_TTL, 'number');
      assert.ok(env.JWT_REFRESH_TTL > 0);
    });

    it('has SMS_PROVIDER', () => {
      const env = getEnv();
      assert.ok(['test', 'aliyun', 'twilio'].includes(env.SMS_PROVIDER));
    });

    it('has PAYMENT_CALLBACK_SECRET', () => {
      const env = getEnv();
      assert.ok(env.PAYMENT_CALLBACK_SECRET);
    });

    it('has LIUYAO_AGENT_URL', () => {
      const env = getEnv();
      assert.ok(typeof env.LIUYAO_AGENT_URL === 'string');
    });

    it('has LIUYAO_AGENT_TOKEN', () => {
      const env = getEnv();
      assert.ok(typeof env.LIUYAO_AGENT_TOKEN === 'string');
    });
  });

  describe('Caching', () => {
    it('returns same object on multiple calls', () => {
      const env1 = getEnv();
      const env2 = getEnv();
      assert.equal(env1, env2, 'should return cached instance');
    });
  });

  describe('Schema validation', () => {
    it('validates all required fields exist', () => {
      const env = getEnv();
      const requiredFields = ['PORT', 'NODE_ENV', 'DATABASE_URL', 'JWT_SECRET', 'JWT_ACCESS_TTL', 'JWT_REFRESH_TTL'];
      for (const field of requiredFields) {
        assert.ok(field in env, `should have ${field}`);
      }
    });

    it('coerces PORT to number', () => {
      const env = getEnv();
      assert.equal(typeof env.PORT, 'number');
    });

    it('coerces JWT_ACCESS_TTL to number', () => {
      const env = getEnv();
      assert.equal(typeof env.JWT_ACCESS_TTL, 'number');
    });
  });
});

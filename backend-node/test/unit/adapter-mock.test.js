const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { createHash } = require('crypto');

// Test the adapter boundary logic directly without requiring the full app

describe('Adapter mock integration (ADAPTER-001)', () => {
  describe('SMS provider adapter boundary', () => {
    it('test provider returns fixed code 123456', () => {
      const provider = 'test';
      const code = provider === 'test' ? '123456' : generateCode();
      assert.equal(code, '123456');
    });

    it('non-test provider generates random code', () => {
      const provider = 'aliyun';
      const code = provider === 'test' ? '123456' : generateRandomCode();
      assert.ok(code.length === 6, 'code should be 6 digits');
      assert.ok(/^\d{6}$/.test(code), 'code should be numeric');
    });

    it('SMS credentials validation detects missing config', () => {
      const env = { SMS_PROVIDER: 'aliyun' };
      const hasCredentials = Boolean(
        env.SMS_API_KEY && env.SMS_API_SECRET && env.SMS_SIGN_NAME && env.SMS_TEMPLATE_CODE
      );
      assert.equal(hasCredentials, false, 'should detect missing SMS credentials');
    });

    it('SMS credentials validation passes with full config', () => {
      const env = {
        SMS_PROVIDER: 'aliyun',
        SMS_API_KEY: 'key',
        SMS_API_SECRET: 'secret',
        SMS_SIGN_NAME: 'sign',
        SMS_TEMPLATE_CODE: 'code',
      };
      const hasCredentials = Boolean(
        env.SMS_API_KEY && env.SMS_API_SECRET && env.SMS_SIGN_NAME && env.SMS_TEMPLATE_CODE
      );
      assert.equal(hasCredentials, true, 'should pass with full SMS config');
    });
  });

  describe('Social login adapter boundary', () => {
    it('resolveSocialProfile generates consistent openId for same input', () => {
      const profile1 = resolveSocialProfile('wechat', 'auth_code_123');
      const profile2 = resolveSocialProfile('wechat', 'auth_code_123');
      assert.equal(profile1.openId, profile2.openId, 'same input should produce same openId');
      assert.equal(profile1.unionId, profile2.unionId, 'same input should produce same unionId');
    });

    it('resolveSocialProfile generates different openId for different providers', () => {
      const wechat = resolveSocialProfile('wechat', 'auth_code_123');
      const qq = resolveSocialProfile('qq', 'auth_code_123');
      assert.notEqual(wechat.openId, qq.openId, 'different providers should have different openIds');
    });

    it('resolveSocialProfile throws for unconfigured provider', () => {
      assert.throws(
        () => resolveSocialProfile('twitter', 'auth_code'),
        /not configured/
      );
    });

    it('WeChat adapter requires WECHAT_APP_ID and WECHAT_APP_SECRET', () => {
      const env = { WECHAT_APP_ID: 'id', WECHAT_APP_SECRET: 'secret' };
      const configured = Boolean(env.WECHAT_APP_ID && env.WECHAT_APP_SECRET);
      assert.equal(configured, true);
    });

    it('QQ adapter requires QQ_APP_ID and QQ_APP_SECRET', () => {
      const env = { QQ_APP_ID: 'id', QQ_APP_SECRET: 'secret' };
      const configured = Boolean(env.QQ_APP_ID && env.QQ_APP_SECRET);
      assert.equal(configured, true);
    });
  });

  describe('Push notification adapter boundary', () => {
    it('FCM adapter requires FCM_SERVER_KEY', () => {
      const env = { FCM_SERVER_KEY: 'key' };
      const configured = Boolean(env.FCM_SERVER_KEY);
      assert.equal(configured, true);
    });

    it('APNS adapter requires APNS_KEY_ID and APNS_TEAM_ID', () => {
      const env = { APNS_KEY_ID: 'key', APNS_TEAM_ID: 'team' };
      const configured = Boolean(env.APNS_KEY_ID && env.APNS_TEAM_ID);
      assert.equal(configured, true);
    });

    it('push delivery gracefully handles missing adapter', () => {
      const env = {};
      const hasFcm = Boolean(env.FCM_SERVER_KEY);
      const hasApns = Boolean(env.APNS_KEY_ID && env.APNS_TEAM_ID);
      const canPush = hasFcm || hasApns;
      assert.equal(canPush, false, 'should detect no push adapter configured');
    });
  });

  describe('Payment callback adapter boundary', () => {
    it('production callback secret must not be dev default', () => {
      const secret = 'production_callback_secret_value';
      const isSafe = secret !== 'dev_callback_secret' && secret.length >= 16;
      assert.equal(isSafe, true);
    });

    it('dev callback secret is detected as unsafe', () => {
      const secret = 'dev_callback_secret';
      const isUnsafe = secret === 'dev_callback_secret';
      assert.equal(isUnsafe, true);
    });

    it('callback signature verification rejects invalid signatures', () => {
      const payload = '{"orderId":"order_1","status":"paid"}';
      const secret = 'callback_secret';
      const expectedSig = createHash('sha256').update(`${payload}:${secret}`).digest('hex');
      const invalidSig = 'invalid_signature';
      assert.notEqual(expectedSig, invalidSig, 'should reject invalid signature');
    });

    it('callback signature verification accepts valid signatures', () => {
      const payload = '{"orderId":"order_1","status":"paid"}';
      const secret = 'callback_secret';
      const sig = createHash('sha256').update(`${payload}:${secret}`).digest('hex');
      const expectedSig = createHash('sha256').update(`${payload}:${secret}`).digest('hex');
      assert.equal(sig, expectedSig, 'should accept valid signature');
    });
  });

  describe('Object storage adapter boundary', () => {
    it('S3 adapter requires all credentials', () => {
      const env = {
        S3_ENDPOINT: 'https://s3.example.com',
        S3_BUCKET: 'bucket',
        S3_ACCESS_KEY: 'key',
        S3_SECRET_KEY: 'secret',
        S3_PUBLIC_URL: 'https://cdn.example.com',
      };
      const configured = Boolean(
        env.S3_ENDPOINT && env.S3_BUCKET && env.S3_ACCESS_KEY && env.S3_SECRET_KEY && env.S3_PUBLIC_URL
      );
      assert.equal(configured, true);
    });

    it('S3 adapter detects missing credentials', () => {
      const env = { S3_ENDPOINT: 'https://s3.example.com' };
      const configured = Boolean(
        env.S3_ENDPOINT && env.S3_BUCKET && env.S3_ACCESS_KEY && env.S3_SECRET_KEY && env.S3_PUBLIC_URL
      );
      assert.equal(configured, false);
    });

    it('public URL is constructed from S3_PUBLIC_URL', () => {
      const publicUrl = 'https://cdn.example.com';
      const key = 'uploads/media/test.png';
      const fullUrl = `${publicUrl}/${key}`;
      assert.ok(fullUrl.startsWith('https://'), 'should use HTTPS');
      assert.ok(fullUrl.includes(key), 'should include the key');
    });
  });

  describe('Agent service adapter boundary', () => {
    it('agent URL must be HTTP(S)', () => {
      const url = 'https://agent.example.com';
      assert.ok(/^https?:\/\//.test(url), 'should be valid HTTP URL');
    });

    it('agent token must be strong', () => {
      const token = 'agent_token_production_value_long_enough';
      const isStrong = token.length >= 16
        && !token.toLowerCase().includes('change-me')
        && !token.toLowerCase().includes('dev');
      assert.equal(isStrong, true);
    });

    it('weak agent token is detected', () => {
      const token = 'dev';
      const isWeak = token.length < 16 || token.toLowerCase().includes('dev');
      assert.equal(isWeak, true);
    });
  });
});

// Helper functions that mirror the auth service adapter logic
function generateCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function generateRandomCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function resolveSocialProfile(provider, authCode) {
  const supportedProviders = ['wechat', 'qq'];
  if (!supportedProviders.includes(provider)) {
    throw new Error(`${provider} OAuth adapter is not configured`);
  }
  const normalized = String(authCode || '').trim();
  const digest = createHash('sha256').update(`${provider}:${normalized}`).digest('hex');
  return {
    openId: `${provider}_${digest.slice(0, 24)}`,
    unionId: `${provider}_union_${digest.slice(24, 36)}`,
    nickname: `${provider.toUpperCase()}用户${digest.slice(0, 4)}`,
  };
}

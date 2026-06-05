const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { runChecks, hasBlockingFailure } = require('../../scripts/adapter-check');

const productionReadyEnv = {
  NODE_ENV: 'production',
  SMS_PROVIDER: 'aliyun',
  SMS_API_KEY: 'sms-api-key',
  SMS_API_SECRET: 'sms-api-secret',
  SMS_SIGN_NAME: '宽窄Orbit',
  SMS_TEMPLATE_CODE: 'SMS_123456',
  WECHAT_APP_ID: 'wechat-app-id',
  WECHAT_APP_SECRET: 'wechat-app-secret',
  QQ_APP_ID: 'qq-app-id',
  QQ_APP_SECRET: 'qq-app-secret',
  S3_ENDPOINT: 'https://s3.example.com',
  S3_BUCKET: 'zhouyi-media',
  S3_ACCESS_KEY: 's3-access-key',
  S3_SECRET_KEY: 's3-secret-key',
  S3_PUBLIC_URL: 'https://cdn.example.com',
  FCM_SERVER_KEY: 'fcm-server-key',
  PAYMENT_CALLBACK_SECRET: 'payment-callback-production-value',
  LIUYAO_AGENT_URL: 'https://agent.example.com',
  LIUYAO_AGENT_TOKEN: 'agent-token-production-value',
};

describe('Adapter check script', () => {
  it('passes a strict production-ready baseline', () => {
    const checks = runChecks({ env: productionReadyEnv, strict: true });
    assert.equal(hasBlockingFailure(checks), false);
  });

  it('blocks strict mode when external adapters are still fallback or missing', () => {
    const checks = runChecks({
      strict: true,
      env: {
        NODE_ENV: 'production',
        SMS_PROVIDER: 'test',
        PAYMENT_CALLBACK_SECRET: 'dev_callback_secret',
      },
    });

    assert.equal(hasBlockingFailure(checks), true);
    assert.ok(checks.some((check) => check.name.includes('SMS provider') && !check.ok));
    assert.ok(checks.some((check) => check.name.includes('Object storage') && !check.ok));
    assert.ok(checks.some((check) => check.name.includes('Payment callback') && !check.ok));
  });

  it('warns but does not block in non-strict local mode', () => {
    const checks = runChecks({
      strict: false,
      env: {
        NODE_ENV: 'development',
        SMS_PROVIDER: 'test',
      },
    });

    assert.equal(hasBlockingFailure(checks), false);
    assert.ok(checks.some((check) => !check.ok && check.severity === 'warn'));
  });
});

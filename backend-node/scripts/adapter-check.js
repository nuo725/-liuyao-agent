#!/usr/bin/env node

require('dotenv').config();

function runChecks({ env = process.env, strict = isStrictMode(process.env) } = {}) {
  const checks = [];

  addCheck(
    checks,
    'SMS provider uses production adapter',
    ['aliyun', 'twilio'].includes(env.SMS_PROVIDER),
    strict ? 'fail' : 'warn',
  );
  addCheck(
    checks,
    'SMS credentials are configured',
    hasAll(env, ['SMS_API_KEY', 'SMS_API_SECRET', 'SMS_SIGN_NAME', 'SMS_TEMPLATE_CODE']),
    strict ? 'fail' : 'warn',
  );
  addCheck(
    checks,
    'WeChat login credentials are configured',
    hasAll(env, ['WECHAT_APP_ID', 'WECHAT_APP_SECRET']),
    strict ? 'fail' : 'warn',
  );
  addCheck(
    checks,
    'QQ login credentials are configured',
    hasAll(env, ['QQ_APP_ID', 'QQ_APP_SECRET']),
    strict ? 'fail' : 'warn',
  );
  addCheck(
    checks,
    'Object storage credentials are configured',
    hasAll(env, ['S3_ENDPOINT', 'S3_BUCKET', 'S3_ACCESS_KEY', 'S3_SECRET_KEY', 'S3_PUBLIC_URL']),
    strict ? 'fail' : 'warn',
  );
  addCheck(
    checks,
    'Push provider credentials are configured',
    hasFcm(env) || hasApns(env),
    strict ? 'fail' : 'warn',
  );
  addCheck(
    checks,
    'Payment callback secret is production strength',
    isStrongSecret(env.PAYMENT_CALLBACK_SECRET) && env.PAYMENT_CALLBACK_SECRET !== 'dev_callback_secret',
    strict ? 'fail' : 'warn',
  );
  addCheck(
    checks,
    'Liuyao Agent service credentials are configured',
    isHttpUrl(env.LIUYAO_AGENT_URL) && isStrongSecret(env.LIUYAO_AGENT_TOKEN),
    strict ? 'fail' : 'warn',
  );

  return checks;
}

function isStrictMode(env) {
  return env.NODE_ENV === 'production' || env.ADAPTER_CHECK_STRICT === '1' || env.ADAPTER_CHECK_STRICT === 'true';
}

function hasAll(env, keys) {
  return keys.every((key) => isFilled(env[key]));
}

function hasFcm(env) {
  return isFilled(env.FCM_SERVER_KEY);
}

function hasApns(env) {
  return hasAll(env, ['APNS_KEY_ID', 'APNS_TEAM_ID']);
}

function isFilled(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function isHttpUrl(value) {
  return typeof value === 'string' && /^https?:\/\//.test(value);
}

function isStrongSecret(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return normalized.length >= 16
    && !normalized.includes('change-me')
    && !normalized.includes('dev')
    && !normalized.includes('secret');
}

function addCheck(checks, name, ok, severity) {
  checks.push({ name, ok: Boolean(ok), severity });
}

function hasBlockingFailure(checks) {
  return checks.some((check) => !check.ok && check.severity === 'fail');
}

function printReport(checks) {
  for (const check of checks) {
    const icon = check.ok ? 'PASS' : check.severity.toUpperCase();
    console.log(`[${icon}] ${check.name}`);
  }
}

if (require.main === module) {
  const checks = runChecks();
  printReport(checks);
  process.exit(hasBlockingFailure(checks) ? 1 : 0);
}

module.exports = {
  runChecks,
  hasBlockingFailure,
};

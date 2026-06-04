#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
require('dotenv').config();

function runChecks({ env = process.env, rootDir = process.cwd(), gitignoreText = null } = {}) {
  const checks = [];
  const nodeEnv = env.NODE_ENV || 'development';
  const gitignore = gitignoreText ?? readIfExists(path.resolve(rootDir, '..', '.gitignore'));

  addCheck(checks, 'DATABASE_URL uses PostgreSQL', isPostgresUrl(env.DATABASE_URL), 'fail');
  addCheck(checks, 'JWT_SECRET is at least 32 characters', String(env.JWT_SECRET || '').length >= 32, 'fail');
  addCheck(checks, 'JWT_SECRET is not a placeholder', !isWeakSecret(env.JWT_SECRET), nodeEnv === 'production' ? 'fail' : 'warn');
  addCheck(
    checks,
    'Production SMS provider is not test',
    !(nodeEnv === 'production' && (env.SMS_PROVIDER || 'test') === 'test'),
    'fail',
  );
  addCheck(
    checks,
    'Production payment callback secret is not dev default',
    !(nodeEnv === 'production' && env.PAYMENT_CALLBACK_SECRET === 'dev_callback_secret'),
    'fail',
  );
  addCheck(checks, 'Local .env is ignored by Git', includesIgnore(gitignore, '/backend-node/.env'), 'fail');
  addCheck(checks, 'Uploaded media is ignored by Git', includesIgnore(gitignore, '/backend-node/uploads/'), 'fail');
  addCheck(checks, 'Database backups are ignored by Git', includesIgnore(gitignore, '/backend-node/backups/'), 'fail');
  addCheck(checks, 'package-lock.json exists', fs.existsSync(path.join(rootDir, 'package-lock.json')), 'warn');

  return checks;
}

function printReport(checks) {
  for (const check of checks) {
    const icon = check.ok ? 'PASS' : check.severity.toUpperCase();
    console.log(`[${icon}] ${check.name}`);
  }
}

function hasBlockingFailure(checks) {
  return checks.some((check) => !check.ok && check.severity === 'fail');
}

function addCheck(checks, name, ok, severity) {
  checks.push({ name, ok: Boolean(ok), severity });
}

function isPostgresUrl(value) {
  return typeof value === 'string' && (value.startsWith('postgresql://') || value.startsWith('postgres://'));
}

function isWeakSecret(value) {
  const normalized = String(value || '').toLowerCase();
  return !normalized
    || normalized.includes('change-me')
    || normalized.includes('secret')
    || normalized.includes('password')
    || normalized === 'dev';
}

function includesIgnore(gitignore, pattern) {
  return String(gitignore || '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .includes(pattern);
}

function readIfExists(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return '';
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

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {
  extractAcceptanceRows,
  formatPreflightReport,
  parseArgs,
  runAcceptancePreflight,
} = require('../../scripts/acceptance-preflight');

const ROOT = path.join(__dirname, '..', '..');

describe('Acceptance preflight', () => {
  it('passes against the current backend workspace', () => {
    const result = runAcceptancePreflight({ rootDir: ROOT });

    assert.equal(result.ok, true);
    assert.ok(result.checks.length > 20);
    assert.equal(result.checks.every((check) => check.status === 'pass'), true);
  });

  it('reports missing package scripts as failed checks', () => {
    const rootDir = makeMinimalWorkspace();
    const packageJson = JSON.parse(fs.readFileSync(path.join(rootDir, 'package.json'), 'utf8'));
    delete packageJson.scripts['ops:acceptance-status'];
    fs.writeFileSync(path.join(rootDir, 'package.json'), JSON.stringify(packageJson), 'utf8');

    const result = runAcceptancePreflight({ rootDir });

    assert.equal(result.ok, false);
    assert.ok(result.checks.some((check) => check.name === 'script:ops:acceptance-status' && check.status === 'fail'));
  });

  it('extracts acceptance rows without table headers', () => {
    const progress = fs.readFileSync(path.join(ROOT, 'PROGRESS.md'), 'utf8');
    const rows = extractAcceptanceRows(progress);

    assert.equal(rows.length, 11);
    assert.equal(rows[0].id, 'CONTRACT-001');
    assert.equal(rows.some((row) => row.id === 'ID'), false);
  });

  it('formats text and json reports', () => {
    const result = {
      ok: false,
      checks: [{ name: 'script:test', status: 'fail', detail: 'missing | broken' }],
    };

    assert.match(formatPreflightReport(result), /Acceptance Preflight/);
    assert.match(formatPreflightReport(result), /missing \\| broken/);
    assert.match(formatPreflightReport(result, { format: 'json' }), /"ok": false/);
  });

  it('parses CLI arguments', () => {
    assert.deepEqual(parseArgs(['--root=backend-node', '--format=json']), {
      rootDir: 'backend-node',
      format: 'json',
    });
  });
});

function makeMinimalWorkspace() {
  const rootDir = fs.mkdtempSync(path.join(os.tmpdir(), 'acceptance-preflight-'));
  copyRequiredFiles(rootDir);
  return rootDir;
}

function copyRequiredFiles(rootDir) {
  for (const file of [
    'package.json',
    'PROGRESS.md',
    'docs/release-acceptance-runbook.md',
    'docs/acceptance-traceability.md',
    'docs/db-migration-baseline.md',
    'docs/adapter-readiness.md',
    'docs/performance-verification.md',
    'prisma/schema.prisma',
    'prisma/migrations/202606050001_initial_schema/migration.sql',
    'prisma/migrations/202606050002_rate_limit_buckets/migration.sql',
    'scripts/acceptance-evidence.js',
    'scripts/acceptance-evidence-validate.js',
    'scripts/acceptance-package.js',
    'scripts/acceptance-status.js',
  ]) {
    copyFile(path.join(ROOT, file), path.join(rootDir, file));
  }
  copyFile(
    path.join(ROOT, '..', 'BACKEND_TDL_AND_DELIVERY_PLAN.md'),
    path.join(rootDir, '..', 'BACKEND_TDL_AND_DELIVERY_PLAN.md'),
  );
  copyFile(path.join(ROOT, '..', 'PRODUCT_PRD.md'), path.join(rootDir, '..', 'PRODUCT_PRD.md'));
}

function copyFile(from, to) {
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(from, to);
}

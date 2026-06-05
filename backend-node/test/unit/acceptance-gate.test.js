const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createAcceptancePackage } = require('../../scripts/acceptance-package');
const { sealAcceptancePackage } = require('../../scripts/acceptance-seal');
const {
  formatGateReport,
  parseArgs,
  runAcceptanceGate,
  summarizeFailedChecks,
} = require('../../scripts/acceptance-gate');

const ROOT = path.join(__dirname, '..', '..');

describe('Acceptance release gate', () => {
  it('passes when preflight, status, and seal are all valid', () => {
    const packageDir = makeCompletedPackage();
    const { sealFile } = sealAcceptancePackage({ packageDir });

    const result = runAcceptanceGate({ rootDir: ROOT, packageDir, sealFile });

    assert.equal(result.ok, true);
    assert.deepEqual(result.checks.map((check) => check.status), ['pass', 'pass', 'pass']);
  });

  it('fails when acceptance evidence is still pending', () => {
    const packageDir = makePackage();
    const { sealFile } = sealAcceptancePackage({ packageDir });

    const result = runAcceptanceGate({ rootDir: ROOT, packageDir, sealFile });

    assert.equal(result.ok, false);
    assert.ok(result.checks.some((check) => check.name === 'acceptance-status' && check.status === 'fail'));
  });

  it('fails when the seal no longer matches the package', () => {
    const packageDir = makeCompletedPackage();
    const { sealFile } = sealAcceptancePackage({ packageDir });
    fs.appendFileSync(path.join(packageDir, 'acceptance-evidence.md'), '\nchanged after gate seal\n', 'utf8');

    const result = runAcceptanceGate({ rootDir: ROOT, packageDir, sealFile });

    assert.equal(result.ok, false);
    assert.ok(result.checks.some((check) => check.name === 'acceptance-seal' && check.status === 'fail'));
  });

  it('requires a package and seal', () => {
    const result = runAcceptanceGate({ rootDir: ROOT });

    assert.equal(result.ok, false);
    assert.ok(result.checks.some((check) => check.name === 'acceptance-status' && check.status === 'fail'));
    assert.ok(result.checks.some((check) => check.name === 'acceptance-seal' && check.status === 'fail'));
  });

  it('formats reports and parses arguments', () => {
    const parsed = parseArgs([
      '--root=backend-node',
      '--package=release-evidence/staging',
      '--format=json',
    ]);

    assert.equal(parsed.rootDir, 'backend-node');
    assert.equal(parsed.packageDir, 'release-evidence/staging');
    assert.match(parsed.sealFile, /release-evidence[\\/]staging[\\/]acceptance-seal\.json/);
    assert.match(formatGateReport({ ok: false, checks: [{ name: 'preflight', status: 'fail', detail: 'bad | detail' }] }), /bad \\| detail/);
  });

  it('summarizes failed checks', () => {
    assert.equal(summarizeFailedChecks([{ name: 'a', status: 'pass' }]), 'ok');
    assert.match(
      summarizeFailedChecks([{ name: 'a', status: 'fail', detail: 'missing' }]),
      /a: missing/,
    );
  });
});

function makePackage() {
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'acceptance-gate-'));
  createAcceptancePackage({
    outDir,
    item: 'DB-001',
    environment: 'staging',
    commit: 'abc1234',
    date: '2026-06-05',
  });
  return outDir;
}

function makeCompletedPackage() {
  const packageDir = makePackage();
  const evidenceFile = path.join(packageDir, 'acceptance-evidence.md');
  const completed = fs.readFileSync(evidenceFile, 'utf8')
    .replaceAll('- [ ] ', '- [x] ')
    .replaceAll('- Status: <pass|fail|partial>', '- Status: pass')
    .replaceAll('- Evidence files/links: <links>', '- Evidence files/links: release/evidence.md')
    .replaceAll('- Follow-up issues: <links or none>', '- Follow-up issues: none')
    .replace('npm run db:restore -- --file=<backup-file> --clean', 'npm run db:restore -- --file=backup.sql --clean');
  fs.writeFileSync(evidenceFile, completed, 'utf8');
  return packageDir;
}

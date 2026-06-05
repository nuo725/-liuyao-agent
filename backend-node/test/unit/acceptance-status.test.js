const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createAcceptancePackage } = require('../../scripts/acceptance-package');
const {
  deriveStatus,
  formatStatusSummary,
  parseArgs,
  parseResultStatus,
  summarizeAcceptancePackage,
} = require('../../scripts/acceptance-status');

describe('Acceptance status summary', () => {
  it('summarizes an unfilled package as pending and not ready', () => {
    const packageDir = makePackage({ item: 'DB-001,OPS-VERIFY-001' });

    const summary = summarizeAcceptancePackage({ packageDir });

    assert.equal(summary.ready, false);
    assert.equal(summary.total, 2);
    assert.equal(summary.passed, 0);
    assert.equal(summary.counts.pending, 2);
    assert.ok(summary.items.every((item) => item.issueCount > 0));
  });

  it('summarizes completed evidence as ready', () => {
    const packageDir = makePackage({ item: 'DB-001' });
    const evidenceFile = path.join(packageDir, 'acceptance-evidence.md');
    const completed = completeEvidence(fs.readFileSync(evidenceFile, 'utf8')).replace(
      'npm run db:restore -- --file=<backup-file> --clean',
      'npm run db:restore -- --file=backup.sql --clean',
    );
    fs.writeFileSync(evidenceFile, completed, 'utf8');

    const summary = summarizeAcceptancePackage({ packageDir });

    assert.equal(summary.ready, true);
    assert.equal(summary.passed, 1);
    assert.equal(summary.items[0].status, 'pass');
    assert.equal(summary.items[0].issueCount, 0);
  });

  it('keeps partial evidence from becoming release-ready', () => {
    const packageDir = makePackage({ item: 'OPS-VERIFY-003' });
    const evidenceFile = path.join(packageDir, 'acceptance-evidence.md');
    const completed = completeEvidence(fs.readFileSync(evidenceFile, 'utf8')).replace('- Status: pass', '- Status: partial');
    fs.writeFileSync(evidenceFile, completed, 'utf8');

    const summary = summarizeAcceptancePackage({ packageDir });

    assert.equal(summary.ready, false);
    assert.equal(summary.items[0].status, 'partial');
    assert.equal(summary.counts.partial, 1);
  });

  it('formats a markdown summary table', () => {
    const message = formatStatusSummary({
      environment: 'staging',
      commit: 'abc1234',
      ready: false,
      passed: 0,
      total: 1,
      items: [{ id: 'DB-001', status: 'pending', issues: ['Status is missing'] }],
    });

    assert.match(message, /Acceptance Package Status/);
    assert.match(message, /\| DB-001 \| pending \| Status is missing \|/);
  });

  it('parses CLI arguments', () => {
    assert.deepEqual(
      parseArgs(['--package=release-evidence/staging', '--format=json']),
      {
        packageDir: 'release-evidence/staging',
        manifestFile: undefined,
        evidenceFile: undefined,
        format: 'json',
      },
    );
  });

  it('parses and derives statuses', () => {
    assert.equal(parseResultStatus('- Status: fail'), 'fail');
    assert.equal(deriveStatus({ validation: { valid: false }, resultStatus: 'pass' }), 'pending');
    assert.equal(deriveStatus({ validation: { valid: true }, resultStatus: 'partial' }), 'partial');
  });
});

function makePackage({ item }) {
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'acceptance-status-'));
  createAcceptancePackage({
    outDir,
    item,
    environment: 'staging',
    commit: 'abc1234',
    date: '2026-06-05',
  });
  return outDir;
}

function completeEvidence(markdown) {
  return markdown
    .replaceAll('- [ ] ', '- [x] ')
    .replaceAll('- Status: <pass|fail|partial>', '- Status: pass')
    .replaceAll('- Evidence files/links: <links>', '- Evidence files/links: release/evidence.md')
    .replaceAll('- Follow-up issues: <links or none>', '- Follow-up issues: none');
}

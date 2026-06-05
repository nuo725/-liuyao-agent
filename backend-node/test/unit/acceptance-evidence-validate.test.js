const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { buildEvidenceReport } = require('../../scripts/acceptance-evidence');
const {
  formatValidationReport,
  parseArgs,
  validateEvidenceMarkdown,
} = require('../../scripts/acceptance-evidence-validate');

describe('Acceptance evidence validation', () => {
  it('rejects an unfilled generated template', () => {
    const markdown = buildEvidenceReport({
      item: 'DB-001',
      environment: 'staging',
      commit: 'abc1234',
      date: '2026-06-05',
    });

    const result = validateEvidenceMarkdown(markdown, { item: 'DB-001' });

    assert.equal(result.valid, false);
    assert.ok(result.issues.some((issue) => issue.message.includes('still unchecked')));
    assert.ok(result.issues.some((issue) => issue.message.includes('Result status')));
  });

  it('accepts a completed item evidence report', () => {
    const markdown = completeEvidence(
      buildEvidenceReport({
        item: 'DB-001',
        environment: 'staging',
        commit: 'abc1234',
        date: '2026-06-05',
      }),
    ).replace('npm run db:restore -- --file=<backup-file> --clean', 'npm run db:restore -- --file=backup.sql --clean');

    const result = validateEvidenceMarkdown(markdown, { item: 'DB-001', requirePass: true });

    assert.equal(result.valid, true);
    assert.equal(result.issueCount, 0);
  });

  it('requires every selected item section to exist', () => {
    const markdown = completeEvidence(
      buildEvidenceReport({
        item: 'OPS-VERIFY-003',
        environment: 'preprod',
        commit: 'abc1234',
        date: '2026-06-05',
      }),
    );

    const result = validateEvidenceMarkdown(markdown, { item: 'DB-001,OPS-VERIFY-003' });

    assert.equal(result.valid, false);
    assert.ok(result.issues.some((issue) => issue.itemId === 'DB-001' && issue.message.includes('missing')));
  });

  it('parses CLI validation arguments', () => {
    assert.deepEqual(
      parseArgs(['--file=release-evidence.md', '--item=ADAPTER-001', '--require-pass=true']),
      {
        file: 'release-evidence.md',
        item: 'ADAPTER-001',
        requirePass: true,
      },
    );
  });

  it('formats failure details for CI logs', () => {
    const message = formatValidationReport({
      valid: false,
      itemIds: ['DB-001'],
      issueCount: 1,
      issues: [{ itemId: 'DB-001', message: 'Result status must be pass, fail, or partial.' }],
    });

    assert.match(message, /Acceptance evidence check failed/);
    assert.match(message, /DB-001: Result status/);
  });
});

function completeEvidence(markdown) {
  return markdown
    .replaceAll('- [ ] ', '- [x] ')
    .replaceAll('- Status: <pass|fail|partial>', '- Status: pass')
    .replaceAll('- Evidence files/links: <links>', '- Evidence files/links: release/evidence.md')
    .replaceAll('- Follow-up issues: <links or none>', '- Follow-up issues: none');
}

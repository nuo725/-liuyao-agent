const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  REMAINING_ITEMS,
  buildEvidenceReport,
  normalizeItems,
  parseArgs,
} = require('../../scripts/acceptance-evidence');

describe('Acceptance evidence template', () => {
  it('builds a report for one acceptance item', () => {
    const report = buildEvidenceReport({
      item: 'DB-001',
      environment: 'staging',
      commit: 'abc1234',
      date: '2026-06-05',
    });

    assert.match(report, /DB-001: Prisma migration baseline and rollback/);
    assert.match(report, /Environment: staging/);
    assert.match(report, /Commit SHA: abc1234/);
    assert.match(report, /npm run db:deploy/);
    assert.doesNotMatch(report, /ADAPTER-001/);
  });

  it('builds a report for every remaining acceptance item by default', () => {
    const report = buildEvidenceReport({ date: '2026-06-05' });

    for (const itemId of Object.keys(REMAINING_ITEMS)) {
      assert.match(report, new RegExp(itemId));
    }
  });

  it('normalizes comma-separated item lists', () => {
    assert.deepEqual(normalizeItems('DB-001,OPS-VERIFY-002'), ['DB-001', 'OPS-VERIFY-002']);
  });

  it('rejects unknown items', () => {
    assert.throws(() => normalizeItems('UNKNOWN-001'), /Unknown acceptance item/);
  });

  it('parses command line arguments', () => {
    const parsed = parseArgs([
      '--item=FE-CONTRACT-001',
      '--environment=preprod',
      '--commit=ff45af8',
      '--date=2026-06-05',
    ]);

    assert.deepEqual(parsed, {
      item: 'FE-CONTRACT-001',
      environment: 'preprod',
      commit: 'ff45af8',
      date: '2026-06-05',
    });
  });
});

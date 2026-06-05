const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const PROGRESS_FILE = path.join(ROOT, 'PROGRESS.md');
const TRACEABILITY_FILE = path.join(ROOT, 'docs', 'acceptance-traceability.md');

describe('Acceptance traceability', () => {
  it('maps every release acceptance item from PROGRESS.md', () => {
    const progress = fs.readFileSync(PROGRESS_FILE, 'utf8');
    const traceability = fs.readFileSync(TRACEABILITY_FILE, 'utf8');
    const acceptanceIds = extractAcceptanceIds(progress);

    assert.deepEqual(acceptanceIds, [
      'CONTRACT-001',
      'DB-001',
      'RATE-001',
      'AGENT-001',
      'TEST-001',
      'TEST-002',
      'OPS-VERIFY-001',
      'OPS-VERIFY-002',
      'OPS-VERIFY-003',
      'FE-CONTRACT-001',
      'ADAPTER-001',
    ]);

    for (const id of acceptanceIds) {
      assert.match(traceability, new RegExp(`\\| ${escapeRegExp(id)} \\|`), `${id} is missing from traceability doc`);
    }
  });

  it('keeps every traceability row tied to both source documents', () => {
    const traceability = fs.readFileSync(TRACEABILITY_FILE, 'utf8');
    const rows = traceability
      .split(/\r?\n/)
      .filter((line) => /^\| [A-Z0-9-]+ \|/.test(line));

    assert.equal(rows.length, 11);
    for (const row of rows) {
      const cells = row.split('|').map((cell) => cell.trim());
      assert.match(cells[3], /Section/i, `${cells[1]} must cite BACKEND_TDL source sections`);
      assert.match(cells[4], /Section/i, `${cells[1]} must cite PRODUCT_PRD source sections`);
    }
  });
});

function extractAcceptanceIds(progress) {
  const start = progress.indexOf('## 上线验收矩阵');
  assert.notEqual(start, -1);
  const rest = progress.slice(start);
  const end = rest.indexOf('**上线验收进度');
  assert.notEqual(end, -1);
  return rest
    .slice(0, end)
    .split(/\r?\n/)
    .map((line) => line.match(/^\| ([A-Z0-9-]+) \|/))
    .filter(Boolean)
    .map((match) => match[1])
    .filter((id) => id !== 'ID');
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

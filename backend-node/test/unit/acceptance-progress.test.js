const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PROGRESS_FILE = path.join(__dirname, '..', '..', 'PROGRESS.md');

describe('Acceptance progress document', () => {
  it('keeps release acceptance counts aligned with the matrix', () => {
    const progress = readProgress();
    const rows = parseAcceptanceRows(progress);
    const completed = rows.filter((row) => row.status.includes('✅')).length;

    assert.equal(rows.length, 11);
    assert.equal(completed, 5);
    assert.deepEqual(readProgressCounts(progress), [
      { completed: 5, total: 11 },
      { completed: 5, total: 11 },
    ]);
  });

  it('keeps remaining external acceptance items visible in next actions', () => {
    const progress = readProgress();
    const nextActions = section(progress, '## 下一步行动', '---');
    const remainingIds = parseAcceptanceRows(progress)
      .filter((row) => !row.status.includes('✅'))
      .map((row) => row.id);

    assert.deepEqual(remainingIds, [
      'DB-001',
      'OPS-VERIFY-001',
      'OPS-VERIFY-002',
      'OPS-VERIFY-003',
      'FE-CONTRACT-001',
      'ADAPTER-001',
    ]);

    for (const id of remainingIds) {
      assert.match(nextActions, new RegExp(`\\*\\*${escapeRegExp(id)}\\*\\*`), `${id} missing from next actions`);
    }
  });

  it('does not mark external-environment items as completed without pass evidence language', () => {
    const rows = parseAcceptanceRows(readProgress());
    const externalRows = rows.filter((row) => row.id.includes('VERIFY') || row.id === 'DB-001' || row.id === 'FE-CONTRACT-001' || row.id === 'ADAPTER-001');

    for (const row of externalRows) {
      assert.doesNotMatch(row.status, /✅/, `${row.id} should remain partial until external evidence exists`);
      assert.match(row.gap, /待|需|仍需/, `${row.id} should describe remaining external evidence`);
    }
  });
});

function readProgress() {
  return fs.readFileSync(PROGRESS_FILE, 'utf8');
}

function parseAcceptanceRows(progress) {
  const matrix = section(progress, '## 上线验收矩阵', '**上线验收进度');
  return matrix
    .split(/\r?\n/)
    .map((line) => line.match(/^\| ([A-Z0-9-]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \|$/))
    .filter(Boolean)
    .map((match) => ({
      id: match[1],
      name: match[2].trim(),
      status: match[3].trim(),
      evidence: match[4].trim(),
      gap: match[5].trim(),
    }))
    .filter((row) => row.id !== 'ID');
}

function readProgressCounts(progress) {
  return [...progress.matchAll(/\*\*上线验收进度：(\d+)\/(\d+)(?: 项完成（\d+%）)?\*\*/g)].map((match) => ({
    completed: Number(match[1]),
    total: Number(match[2]),
  }));
}

function section(markdown, startMarker, endMarker) {
  const start = markdown.indexOf(startMarker);
  assert.notEqual(start, -1, `${startMarker} section not found`);
  const rest = markdown.slice(start);
  const end = rest.indexOf(endMarker, startMarker.length);
  assert.notEqual(end, -1, `${endMarker} marker not found after ${startMarker}`);
  return rest.slice(0, end);
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

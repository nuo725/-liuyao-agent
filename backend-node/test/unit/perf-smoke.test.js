const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { summarizeResults } = require('../../scripts/perf-smoke');

describe('Performance smoke summary', () => {
  it('calculates latency percentiles and error rate', () => {
    const summary = summarizeResults([
      { ok: true, status: 200, durationMs: 10 },
      { ok: true, status: 200, durationMs: 20 },
      { ok: false, status: 503, durationMs: 40 },
      { ok: true, status: 200, durationMs: 30 },
    ]);

    assert.equal(summary.total, 4);
    assert.equal(summary.failures, 1);
    assert.equal(summary.errorRate, 0.25);
    assert.equal(summary.p50Ms, 20);
    assert.equal(summary.p95Ms, 40);
    assert.equal(summary.statusCodes[200], 3);
    assert.equal(summary.statusCodes[503], 1);
  });
});

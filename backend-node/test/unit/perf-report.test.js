const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { summarizeResults } = require('../../scripts/perf-smoke');

describe('Performance report generation (OPS-VERIFY-002)', () => {
  describe('Result summarization', () => {
    it('calculates correct statistics for successful results', () => {
      const results = [
        { ok: true, status: 200, durationMs: 50 },
        { ok: true, status: 200, durationMs: 100 },
        { ok: true, status: 200, durationMs: 150 },
        { ok: true, status: 200, durationMs: 200 },
        { ok: true, status: 200, durationMs: 250 },
      ];

      const summary = summarizeResults(results);

      assert.equal(summary.total, 5);
      assert.equal(summary.failures, 0);
      assert.equal(summary.errorRate, 0);
      assert.equal(summary.minMs, 50);
      assert.equal(summary.maxMs, 250);
      assert.ok(summary.avgMs > 0, 'avgMs should be positive');
      assert.ok(summary.p50Ms > 0, 'p50Ms should be positive');
      assert.ok(summary.p95Ms > 0, 'p95Ms should be positive');
    });

    it('calculates correct error rate', () => {
      const results = [
        { ok: true, status: 200, durationMs: 50 },
        { ok: false, status: 500, durationMs: 100 },
        { ok: true, status: 200, durationMs: 150 },
        { ok: false, status: 500, durationMs: 200 },
        { ok: true, status: 200, durationMs: 250 },
      ];

      const summary = summarizeResults(results);

      assert.equal(summary.total, 5);
      assert.equal(summary.failures, 2);
      assert.equal(summary.errorRate, 0.4);
    });

    it('counts status codes correctly', () => {
      const results = [
        { ok: true, status: 200, durationMs: 50 },
        { ok: true, status: 200, durationMs: 100 },
        { ok: false, status: 500, durationMs: 150 },
        { ok: false, status: 404, durationMs: 200 },
      ];

      const summary = summarizeResults(results);

      assert.equal(summary.statusCodes[200], 2);
      assert.equal(summary.statusCodes[500], 1);
      assert.equal(summary.statusCodes[404], 1);
    });

    it('handles timeout results', () => {
      const results = [
        { ok: true, status: 200, durationMs: 50 },
        { ok: false, status: 'timeout', durationMs: 5000 },
      ];

      const summary = summarizeResults(results);

      assert.equal(summary.total, 2);
      assert.equal(summary.failures, 1);
      assert.equal(summary.statusCodes['timeout'], 1);
    });

    it('handles empty results', () => {
      const summary = summarizeResults([]);

      assert.equal(summary.total, 0);
      assert.equal(summary.failures, 0);
      assert.equal(summary.errorRate, 0);
      assert.equal(summary.minMs, 0);
      assert.equal(summary.avgMs, 0);
      assert.equal(summary.p50Ms, 0);
      assert.equal(summary.p95Ms, 0);
      assert.equal(summary.maxMs, 0);
    });

    it('handles single result', () => {
      const results = [
        { ok: true, status: 200, durationMs: 42 },
      ];

      const summary = summarizeResults(results);

      assert.equal(summary.total, 1);
      assert.equal(summary.failures, 0);
      assert.equal(summary.minMs, 42);
      assert.equal(summary.maxMs, 42);
      assert.equal(summary.p50Ms, 42);
      assert.equal(summary.p95Ms, 42);
    });
  });

  describe('Percentile calculation', () => {
    it('p50 is median', () => {
      const results = Array.from({ length: 100 }, (_, i) => ({
        ok: true,
        status: 200,
        durationMs: i + 1,
      }));

      const summary = summarizeResults(results);

      assert.equal(summary.p50Ms, 50, `p50 should be ~50, got ${summary.p50Ms}`);
    });

    it('p95 is 95th percentile', () => {
      const results = Array.from({ length: 100 }, (_, i) => ({
        ok: true,
        status: 200,
        durationMs: i + 1,
      }));

      const summary = summarizeResults(results);

      assert.equal(summary.p95Ms, 95, `p95 should be ~95, got ${summary.p95Ms}`);
    });
  });

  describe('Report formatting', () => {
    it('report can be serialized to JSON', () => {
      const results = [
        { ok: true, status: 200, durationMs: 50 },
        { ok: false, status: 500, durationMs: 100 },
      ];

      const summary = summarizeResults(results);
      const json = JSON.stringify(summary, null, 2);

      assert.ok(json.length > 0, 'should serialize to non-empty JSON');
      const parsed = JSON.parse(json);
      assert.equal(parsed.total, 2);
      assert.equal(parsed.failures, 1);
    });

    it('report includes all required fields', () => {
      const results = [{ ok: true, status: 200, durationMs: 50 }];
      const summary = summarizeResults(results);

      const requiredFields = ['total', 'failures', 'errorRate', 'minMs', 'avgMs', 'p50Ms', 'p95Ms', 'maxMs', 'statusCodes'];
      for (const field of requiredFields) {
        assert.ok(field in summary, `report should have ${field} field`);
      }
    });
  });

  describe('Threshold validation', () => {
    it('passes when p95 is below threshold', () => {
      const results = Array.from({ length: 100 }, (_, i) => ({
        ok: true,
        status: 200,
        durationMs: i + 1,
      }));

      const summary = summarizeResults(results);
      const maxP95Ms = 200;
      const passed = summary.p95Ms <= maxP95Ms;

      assert.equal(passed, true);
    });

    it('fails when p95 exceeds threshold', () => {
      const results = Array.from({ length: 100 }, (_, i) => ({
        ok: true,
        status: 200,
        durationMs: (i + 1) * 10,
      }));

      const summary = summarizeResults(results);
      const maxP95Ms = 500;
      const passed = summary.p95Ms <= maxP95Ms;

      assert.equal(passed, false, `p95 ${summary.p95Ms} should exceed ${maxP95Ms}`);
    });

    it('passes when error rate is below threshold', () => {
      const results = [
        { ok: true, status: 200, durationMs: 50 },
        { ok: true, status: 200, durationMs: 100 },
        { ok: false, status: 500, durationMs: 150 },
      ];

      const summary = summarizeResults(results);
      const maxErrorRate = 0.5;
      const passed = summary.errorRate <= maxErrorRate;

      assert.equal(passed, true);
    });

    it('fails when error rate exceeds threshold', () => {
      const results = [
        { ok: false, status: 500, durationMs: 50 },
        { ok: false, status: 500, durationMs: 100 },
        { ok: true, status: 200, durationMs: 150 },
      ];

      const summary = summarizeResults(results);
      const maxErrorRate = 0.01;
      const passed = summary.errorRate <= maxErrorRate;

      assert.equal(passed, false);
    });
  });
});

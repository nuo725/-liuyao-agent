const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { summarizeResults, parseArgs, runLoadTest } = require('../../scripts/perf-smoke');

describe('Perf smoke validation (OPS-004)', () => {
  describe('summarizeResults', () => {
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
      const summary = summarizeResults([{ ok: true, status: 200, durationMs: 42 }]);
      assert.equal(summary.total, 1);
      assert.equal(summary.failures, 0);
      assert.equal(summary.minMs, 42);
      assert.equal(summary.maxMs, 42);
      assert.equal(summary.p50Ms, 42);
      assert.equal(summary.p95Ms, 42);
    });

    it('calculates correct statistics', () => {
      const results = [
        { ok: true, status: 200, durationMs: 10 },
        { ok: true, status: 200, durationMs: 20 },
        { ok: true, status: 200, durationMs: 30 },
        { ok: true, status: 200, durationMs: 40 },
        { ok: true, status: 200, durationMs: 50 },
      ];
      const summary = summarizeResults(results);
      assert.equal(summary.total, 5);
      assert.equal(summary.minMs, 10);
      assert.equal(summary.maxMs, 50);
      assert.equal(summary.avgMs, 30);
    });

    it('calculates error rate correctly', () => {
      const results = [
        { ok: true, status: 200, durationMs: 10 },
        { ok: false, status: 500, durationMs: 20 },
        { ok: true, status: 200, durationMs: 30 },
        { ok: false, status: 500, durationMs: 40 },
      ];
      const summary = summarizeResults(results);
      assert.equal(summary.total, 4);
      assert.equal(summary.failures, 2);
      assert.equal(summary.errorRate, 0.5);
    });

    it('counts status codes', () => {
      const results = [
        { ok: true, status: 200, durationMs: 10 },
        { ok: true, status: 200, durationMs: 20 },
        { ok: false, status: 500, durationMs: 30 },
        { ok: false, status: 404, durationMs: 40 },
      ];
      const summary = summarizeResults(results);
      assert.equal(summary.statusCodes[200], 2);
      assert.equal(summary.statusCodes[500], 1);
      assert.equal(summary.statusCodes[404], 1);
    });

    it('handles timeout status', () => {
      const results = [
        { ok: true, status: 200, durationMs: 10 },
        { ok: false, status: 'timeout', durationMs: 5000 },
      ];
      const summary = summarizeResults(results);
      assert.equal(summary.statusCodes['timeout'], 1);
    });
  });

  describe('Percentile calculation', () => {
    it('p50 is median for odd count', () => {
      const results = [
        { ok: true, status: 200, durationMs: 10 },
        { ok: true, status: 200, durationMs: 20 },
        { ok: true, status: 200, durationMs: 30 },
      ];
      const summary = summarizeResults(results);
      assert.equal(summary.p50Ms, 20);
    });

    it('p95 is 95th percentile', () => {
      const results = Array.from({ length: 100 }, (_, i) => ({
        ok: true, status: 200, durationMs: i + 1,
      }));
      const summary = summarizeResults(results);
      assert.equal(summary.p95Ms, 95);
    });
  });

  describe('parseArgs', () => {
    it('parses URL argument', () => {
      const result = parseArgs(['--url=https://api.example.com/health']);
      assert.equal(result.url, 'https://api.example.com/health');
    });

    it('parses requests argument', () => {
      const result = parseArgs(['--requests=500']);
      assert.equal(result.requests, 500);
    });

    it('parses concurrency argument', () => {
      const result = parseArgs(['--concurrency=25']);
      assert.equal(result.concurrency, 25);
    });

    it('parses maxP95Ms argument', () => {
      const result = parseArgs(['--maxP95Ms=800']);
      assert.equal(result.maxP95Ms, 800);
    });

    it('parses maxErrorRate argument', () => {
      const result = parseArgs(['--maxErrorRate=0.01']);
      assert.equal(result.maxErrorRate, 0.01);
    });

    it('defaults when no args', () => {
      const result = parseArgs([]);
      assert.ok(result.url, 'should have default url');
      assert.ok(result.requests > 0, 'should have default requests');
      assert.ok(result.concurrency > 0, 'should have default concurrency');
    });
  });

  describe('Threshold validation', () => {
    it('passes when p95 is below threshold', () => {
      const results = Array.from({ length: 100 }, (_, i) => ({
        ok: true, status: 200, durationMs: i + 1,
      }));
      const summary = summarizeResults(results);
      assert.equal(summary.p95Ms <= 200, true);
    });

    it('fails when p95 exceeds threshold', () => {
      const results = Array.from({ length: 100 }, (_, i) => ({
        ok: true, status: 200, durationMs: (i + 1) * 10,
      }));
      const summary = summarizeResults(results);
      assert.equal(summary.p95Ms <= 500, false);
    });

    it('passes when error rate is below threshold', () => {
      const results = [
        { ok: true, status: 200, durationMs: 10 },
        { ok: true, status: 200, durationMs: 20 },
        { ok: false, status: 500, durationMs: 30 },
      ];
      const summary = summarizeResults(results);
      assert.equal(summary.errorRate <= 0.5, true);
    });

    it('fails when error rate exceeds threshold', () => {
      const results = [
        { ok: false, status: 500, durationMs: 10 },
        { ok: false, status: 500, durationMs: 20 },
        { ok: true, status: 200, durationMs: 30 },
      ];
      const summary = summarizeResults(results);
      assert.equal(summary.errorRate <= 0.01, false);
    });
  });

  describe('Load test execution', () => {
    it('runLoadTest returns summary with pass/fail', async () => {
      const http = require('http');
      const server = http.createServer((req, res) => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true }));
      });

      await new Promise((resolve) => {
        server.listen(0, '127.0.0.1', async () => {
          const { port } = server.address();
          try {
            const summary = await runLoadTest({
              url: `http://127.0.0.1:${port}/test`,
              requests: 10,
              concurrency: 2,
              timeoutMs: 5000,
              maxP95Ms: 5000,
              maxErrorRate: 0.1,
            });

            assert.equal(summary.total, 10);
            assert.equal(summary.failures, 0);
            assert.ok(summary.passed, 'should pass with low latency');
            assert.ok(summary.p95Ms > 0, 'should have p95');
          } finally {
            server.close(resolve);
          }
        });
      });
    });

    it('runLoadTest fails when error rate exceeds threshold', async () => {
      const http = require('http');
      const server = http.createServer((req, res) => {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'fail' }));
      });

      await new Promise((resolve) => {
        server.listen(0, '127.0.0.1', async () => {
          const { port } = server.address();
          try {
            const summary = await runLoadTest({
              url: `http://127.0.0.1:${port}/test`,
              requests: 10,
              concurrency: 2,
              timeoutMs: 5000,
              maxP95Ms: 5000,
              maxErrorRate: 0.01,
            });

            assert.equal(summary.total, 10);
            assert.equal(summary.failures, 10);
            assert.equal(summary.passed, false, 'should fail with 100% error rate');
          } finally {
            server.close(resolve);
          }
        });
      });
    });
  });
});

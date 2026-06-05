const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { buildHeaders, runScenarioSuite } = require('../../scripts/perf-scenarios');

describe('Performance scenario suite', () => {
  it('builds auth and idempotency headers for write scenarios', () => {
    const headers = buildHeaders(
      { name: 'comment_create', required: ['PERF_AUTH_TOKEN'], idempotent: true },
      { token: 'token_value', runId: 'run_1' },
    );

    assert.equal(headers.Authorization, 'Bearer token_value');
    assert.equal(headers['Idempotency-Key'], 'perf-comment_create-run_1');
  });

  it('marks scenarios with missing environment as skipped and not passed', async () => {
    const report = await runScenarioSuite({
      env: {},
      scenarios: [
        {
          name: 'comment_create',
          method: 'POST',
          path: '/api/v1/community/post/post_1/comments',
          required: ['PERF_AUTH_TOKEN'],
        },
      ],
      loadTest: async () => {
        throw new Error('load test should not run');
      },
    });

    assert.equal(report.passed, false);
    assert.equal(report.results[0].skipped, true);
    assert.match(report.results[0].reason, /PERF_AUTH_TOKEN/);
  });

  it('runs configured scenarios through the load test helper', async () => {
    const calls = [];
    const report = await runScenarioSuite({
      baseUrl: 'https://api.example.com/',
      env: { PERF_RUN_ID: 'run_2' },
      requests: 5,
      concurrency: 2,
      scenarios: [
        {
          name: 'community_feed',
          method: 'GET',
          path: '/api/v1/community/feed',
        },
      ],
      loadTest: async (options) => {
        calls.push(options);
        return { passed: true, p95Ms: 30, errorRate: 0 };
      },
    });

    assert.equal(report.passed, true);
    assert.equal(calls[0].url, 'https://api.example.com/api/v1/community/feed');
    assert.equal(calls[0].requests, 5);
    assert.equal(calls[0].concurrency, 2);
  });
});

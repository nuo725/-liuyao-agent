const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { buildHeaders, runScenarioSuite, DEFAULT_SCENARIOS } = require('../../scripts/perf-scenarios');

describe('Performance scenario suite', () => {
  it('builds auth and idempotency headers for write scenarios', () => {
    const headers = buildHeaders(
      { name: 'comment_create', required: ['PERF_AUTH_TOKEN'], idempotent: true },
      { token: 'token_value', runId: 'run_1' },
    );

    assert.equal(headers.Authorization, 'Bearer token_value');
    assert.equal(headers['Idempotency-Key'], 'perf-comment_create-run_1');
  });

  it('does not add Authorization header for non-auth scenarios', () => {
    const headers = buildHeaders(
      { name: 'community_feed_recommended', required: [] },
      { token: 'token_value', runId: 'run_1' },
    );

    assert.equal(headers.Authorization, undefined);
    assert.equal(headers['Idempotency-Key'], undefined);
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
          name: 'community_feed_recommended',
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

  it('exports at least 15 default scenarios covering all major modules', () => {
    assert.ok(DEFAULT_SCENARIOS.length >= 15, `Expected >= 15 scenarios, got ${DEFAULT_SCENARIOS.length}`);
    const names = DEFAULT_SCENARIOS.map((s) => s.name);
    // Public endpoints
    assert.ok(names.includes('community_feed_recommended'));
    assert.ok(names.includes('community_feed_deep'));
    assert.ok(names.includes('post_detail'));
    assert.ok(names.includes('post_comments'));
    assert.ok(names.includes('activity_list'));
    assert.ok(names.includes('billing_plans'));
    assert.ok(names.includes('health'));
    // Authenticated reads
    assert.ok(names.includes('profile_me'));
    assert.ok(names.includes('notifications_list'));
    assert.ok(names.includes('notifications_unread_count'));
    assert.ok(names.includes('credits_account'));
    assert.ok(names.includes('match_same_frequency'));
    // Authenticated writes
    assert.ok(names.includes('comment_create'));
    assert.ok(names.includes('ritual_perform'));
  });

  it('resolves dynamic path functions for scenarios with postId', async () => {
    const calls = [];
    await runScenarioSuite({
      baseUrl: 'https://api.example.com',
      env: { PERF_POST_ID: 'post_123', PERF_RUN_ID: 'run_3' },
      requests: 1,
      concurrency: 1,
      scenarios: [
        {
          name: 'post_detail',
          method: 'GET',
          path: ({ postId }) => `/api/v1/community/post/${postId}`,
          required: ['PERF_POST_ID'],
        },
      ],
      loadTest: async (options) => {
        calls.push(options);
        return { passed: true, p95Ms: 10, errorRate: 0 };
      },
    });

    assert.equal(calls[0].url, 'https://api.example.com/api/v1/community/post/post_123');
  });
});

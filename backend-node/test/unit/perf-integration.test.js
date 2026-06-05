const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const { runScenarioSuite } = require('../../scripts/perf-scenarios');

function createMockServer(handler) {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let body = '';
      req.on('data', (chunk) => { body += chunk; });
      req.on('end', () => {
        const result = handler(req, body);
        res.writeHead(result.status || 200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result.body || { success: true, data: {} }));
      });
    });
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      resolve({ server, port, baseUrl: `http://127.0.0.1:${port}` });
    });
  });
}

describe('Performance scenario integration (OPS-VERIFY-002)', () => {
  let mockServer;
  let baseUrl;

  before(async () => {
    const { server, baseUrl: url } = await createMockServer((req) => {
      // Simulate realistic response times
      const path = req.url;
      if (path.includes('/health')) {
        return { status: 200, body: { success: true, data: { status: 'ok' } } };
      }
      if (path.includes('/community/feed')) {
        return { status: 200, body: { success: true, data: { items: [], hasMore: false } } };
      }
      if (path.includes('/community/search')) {
        return { status: 200, body: { success: true, data: { items: [], total: 0 } } };
      }
      if (path.includes('/community/post/') && path.includes('/comments') && req.method === 'POST') {
        return { status: 200, body: { success: true, data: { id: 'comment_1', text: 'test' } } };
      }
      if (path.includes('/community/post/')) {
        return { status: 200, body: { success: true, data: { id: 'post_1' } } };
      }
      if (path.includes('/profile/me')) {
        return { status: 200, body: { success: true, data: { id: 'user_1', username: 'test' } } };
      }
      if (path.includes('/notifications/unread-count')) {
        return { status: 200, body: { success: true, data: { count: 0 } } };
      }
      if (path.includes('/notifications')) {
        return { status: 200, body: { success: true, data: { items: [], unreadCount: 0 } } };
      }
      if (path.includes('/credits/account')) {
        return { status: 200, body: { success: true, data: { castBalance: 10, followupBalance: 5, isVip: false } } };
      }
      if (path.includes('/match/same-frequency')) {
        return { status: 200, body: { success: true, data: { users: [] } } };
      }
      if (path.includes('/activities/list')) {
        return { status: 200, body: { success: true, data: { items: [], hasMore: false } } };
      }
      if (path.includes('/billing/plans')) {
        return { status: 200, body: { success: true, data: { plans: [] } } };
      }
      if (path.includes('/ritual/perform')) {
        return { status: 200, body: { success: true, data: { sessionId: 'session_1', tag: 'other', pattern: {} } } };
      }
      return { status: 200, body: { success: true, data: {} } };
    });
    mockServer = server;
    baseUrl = url;
  });

  after((done) => {
    mockServer.close(done);
  });

  it('runs all default scenarios against mock server with low concurrency', async () => {
    const report = await runScenarioSuite({
      baseUrl,
      env: {
        PERF_AUTH_TOKEN: 'test-token',
        PERF_POST_ID: 'post_1',
        PERF_RUN_ID: 'integration-test-1',
      },
      requests: 5,
      concurrency: 2,
      timeoutMs: 5000,
      maxP95Ms: 2000,
      maxErrorRate: 0.01,
    });

    assert.equal(report.passed, true, `All scenarios should pass. Results: ${JSON.stringify(report.results.map(r => ({ name: r.name, passed: r.passed, skipped: r.skipped })))}`);
    assert.ok(report.results.length >= 15, `Should run at least 15 scenarios, got ${report.results.length}`);

    // Verify all scenarios ran (not skipped)
    const skipped = report.results.filter((r) => r.skipped);
    const passed = report.results.filter((r) => r.passed && !r.skipped);
    assert.equal(skipped.length, 0, `No scenarios should be skipped: ${skipped.map(s => s.name).join(', ')}`);
    assert.ok(passed.length >= 15, `At least 15 scenarios should pass`);
  });

  it('reports correct structure for each scenario result', async () => {
    const report = await runScenarioSuite({
      baseUrl,
      env: { PERF_RUN_ID: 'integration-test-2' },
      requests: 3,
      concurrency: 1,
      scenarios: [
        { name: 'health', method: 'GET', path: '/api/v1/health' },
      ],
      maxP95Ms: 2000,
      maxErrorRate: 0.01,
    });

    assert.equal(report.results.length, 1);
    const result = report.results[0];
    assert.equal(result.name, 'health');
    assert.equal(result.passed, true);
    assert.ok(result.summary, 'should have summary');
    assert.ok(typeof result.summary.total === 'number', 'should have total');
    assert.ok(typeof result.summary.p50Ms === 'number', 'should have p50Ms');
    assert.ok(typeof result.summary.p95Ms === 'number', 'should have p95Ms');
    assert.ok(typeof result.summary.errorRate === 'number', 'should have errorRate');
  });

  it('marks scenarios as failed when server returns errors', async () => {
    const { server: failServer, baseUrl: failBaseUrl } = await createMockServer(() => {
      return { status: 500, body: { success: false, error: { code: 'INTERNAL', message: 'fail' } } };
    });

    try {
      const report = await runScenarioSuite({
        baseUrl: failBaseUrl,
        env: { PERF_RUN_ID: 'integration-test-3' },
        requests: 5,
        concurrency: 2,
        scenarios: [
          { name: 'failing_endpoint', method: 'GET', path: '/api/v1/test' },
        ],
        maxP95Ms: 2000,
        maxErrorRate: 0.01,
      });

      assert.equal(report.passed, false, 'should fail when error rate exceeds threshold');
      assert.equal(report.results[0].passed, false);
    } finally {
      failServer.close();
    }
  });

  it('skips scenarios with missing required env vars', async () => {
    const report = await runScenarioSuite({
      baseUrl,
      env: {},  // No PERF_AUTH_TOKEN or PERF_POST_ID
      requests: 3,
      concurrency: 1,
      maxP95Ms: 2000,
      maxErrorRate: 0.01,
    });

    // Some scenarios require PERF_AUTH_TOKEN or PERF_POST_ID
    const skipped = report.results.filter((r) => r.skipped);
    const passed = report.results.filter((r) => r.passed && !r.skipped);
    assert.ok(skipped.length > 0, 'Some scenarios should be skipped without auth token');
    assert.ok(passed.length > 0, 'Public scenarios should still pass');
  });

  it('uses dynamic path functions correctly', async () => {
    const report = await runScenarioSuite({
      baseUrl,
      env: { PERF_POST_ID: 'post_dynamic_123', PERF_RUN_ID: 'integration-test-5' },
      requests: 3,
      concurrency: 1,
      scenarios: [
        {
          name: 'post_detail_dynamic',
          method: 'GET',
          path: ({ postId }) => `/api/v1/community/post/${postId}`,
          required: ['PERF_POST_ID'],
        },
      ],
      maxP95Ms: 2000,
      maxErrorRate: 0.01,
    });

    assert.equal(report.results[0].passed, true);
    assert.equal(report.results[0].path, '/api/v1/community/post/post_dynamic_123');
  });
});

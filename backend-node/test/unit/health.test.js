// Health Check Integration Test
// Verifies the /api/v1/health endpoint and basic app wiring.

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createTestApp } = require('../helpers/setup');
const { startTestApp, stopTestApp } = require('../helpers/http');

describe('Health Check', () => {
  let server, client;

  before(async () => {
    const app = createTestApp();
    ({ server, client } = await startTestApp(app));
  });

  after(async () => {
    await stopTestApp(server);
  });

  it('GET /api/v1/health returns envelope with status', async () => {
    const res = await client.get('/api/v1/health');
    // Accept 200 (DB connected) or 503 (DB disconnected)
    assert.ok([200, 503].includes(res.status), `unexpected status: ${res.status}`);
    assert.equal(res.body.success, true, 'expected success=true');
    assert.ok(res.body.data.status, 'expected status field');
    assert.ok(
      res.body.data.status === 'ok' || res.body.data.status === 'degraded',
      `unexpected status value: ${res.body.data.status}`
    );
    assert.ok(res.body.data.time, 'expected time field');
  });

  it('GET /api/v1/health includes requestId header', async () => {
    const res = await client.get('/api/v1/health');
    const requestId = res.headers.get('x-request-id');
    assert.ok(requestId, 'expected X-Request-Id header');
    assert.ok(requestId.startsWith('req_'), 'expected req_ prefix');
  });
});

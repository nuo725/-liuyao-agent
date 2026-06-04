// Error Format Integration Test
// Verifies that 404 and error responses follow the standard envelope.

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createTestApp, assertFailEnvelope } = require('../helpers/setup');
const { startTestApp, stopTestApp } = require('../helpers/http');

describe('Error Format', () => {
  let server, client;

  before(async () => {
    const app = createTestApp();
    ({ server, client } = await startTestApp(app));
  });

  after(async () => {
    await stopTestApp(server);
  });

  it('404 returns standard fail envelope with 40401', async () => {
    const res = await client.get('/api/v1/nonexistent');
    assert.equal(res.status, 404);
    assertFailEnvelope({ assert: assert.ok }, res.body, '40401');
  });

  it('404 includes requestId', async () => {
    const res = await client.get('/api/v1/nonexistent');
    assert.ok(res.body.requestId, 'expected requestId in error response');
  });

  it('404 error has message field', async () => {
    const res = await client.get('/api/v1/nonexistent');
    assert.ok(
      res.body.error.message.includes('not implemented') ||
      res.body.error.message.includes('Not implemented') ||
      res.body.error.message.includes('Route not'),
      `unexpected message: ${res.body.error.message}`
    );
  });
});

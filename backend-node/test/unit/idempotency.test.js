const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { createIdempotency, idempotency } = require('../../src/middleware/idempotency');

describe('Idempotency middleware', () => {
  it('calls next() when no Idempotency-Key header', async () => {
    const calls = [];
    const req = { headers: {}, method: 'POST' };
    await idempotency(req, {}, () => calls.push('next'));
    assert.equal(calls.length, 1);
  });

  it('calls next() for GET requests even with key', async () => {
    const calls = [];
    const req = { headers: { 'idempotency-key': 'key_1' }, method: 'GET' };
    await idempotency(req, {}, () => calls.push('next'));
    assert.equal(calls.length, 1);
  });

  it('calls next() for POST with Idempotency-Key (first time)', async () => {
    const calls = [];
    const req = { headers: { 'idempotency-key': 'key_new_' + Date.now() }, method: 'POST', userId: 'user_1' };
    const res = { statusCode: 200, json: (body) => body };
    await idempotency(req, res, () => calls.push('next'));
    assert.equal(calls.length, 1);
  });

  it('returns cached response for duplicate key', async () => {
    const key = 'key_dup_' + Date.now();
    const userId = 'user_dup';
    const req = { headers: { 'idempotency-key': key }, method: 'POST', userId };
    const res = {
      statusCode: 200,
      json: (body) => body,
    };

    // First call - processes normally
    await idempotency(req, res, () => {});
    await res.json({ success: true, data: { id: 'order_1' } });

    // Second call - should return cached
    let cachedBody;
    const req2 = { headers: { 'idempotency-key': key }, method: 'POST', userId };
    const res2 = {
      status: () => ({ json: (body) => { cachedBody = body; } }),
    };
    await idempotency(req2, res2, () => { throw new Error('should not call next'); });

    assert.deepEqual(cachedBody, { success: true, data: { id: 'order_1' } });
  });

  it('does not cache error responses', async () => {
    const key = 'key_err_' + Date.now();
    const userId = 'user_err';
    const req = { headers: { 'idempotency-key': key }, method: 'POST', userId };
    const res = {
      statusCode: 400,
      json: (body) => body,
    };

    // First call - error response
    await idempotency(req, res, () => {});
    await res.json({ success: false, error: { code: '40001' } });

    // Second call - should NOT return cached
    const calls = [];
    const req2 = { headers: { 'idempotency-key': key }, method: 'POST', userId };
    const res2 = { statusCode: 200, json: (body) => body };
    await idempotency(req2, res2, () => calls.push('next'));

    assert.equal(calls.length, 1, 'should call next for non-cached error');
  });

  it('uses anonymous userId when not authenticated', async () => {
    const key = 'key_anon_' + Date.now();
    const req = { headers: { 'idempotency-key': key }, method: 'POST' };
    const res = {
      statusCode: 200,
      json: (body) => body,
    };

    await idempotency(req, res, () => {});
    await res.json({ success: true });

    // Second call with same key, no userId
    let cachedBody;
    const req2 = { headers: { 'idempotency-key': key }, method: 'POST' };
    const res2 = {
      status: () => ({ json: (body) => { cachedBody = body; } }),
    };
    await idempotency(req2, res2, () => {});

    assert.deepEqual(cachedBody, { success: true });
  });

  it('can replay a response from an injected persistent store', async () => {
    const store = {
      get: async () => ({
        requestHash: 'known_hash',
        response: {
          status: 201,
          body: { success: true, data: { id: 'persisted_order' } },
        },
      }),
      set: async () => {
        throw new Error('should not write on replay');
      },
      hashRequest: () => 'known_hash',
    };
    const middleware = createIdempotency({ store });
    const req = {
      headers: { 'idempotency-key': 'persisted_key' },
      method: 'POST',
      userId: 'user_persisted',
      originalUrl: '/api/v1/billing/orders',
      body: { planId: 'vip_monthly' },
    };
    let replay;
    const res = {
      status: (status) => ({
        json: (body) => {
          replay = { status, body };
        },
      }),
    };

    await middleware(req, res, () => {
      throw new Error('should not call next');
    });

    assert.deepEqual(replay, {
      status: 201,
      body: { success: true, data: { id: 'persisted_order' } },
    });
  });

});

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { idempotency } = require('../../src/middleware/idempotency');

describe('Idempotency middleware', () => {
  it('calls next() when no Idempotency-Key header', () => {
    const calls = [];
    const req = { headers: {}, method: 'POST' };
    idempotency(req, {}, () => calls.push('next'));
    assert.equal(calls.length, 1);
  });

  it('calls next() for GET requests even with key', () => {
    const calls = [];
    const req = { headers: { 'idempotency-key': 'key_1' }, method: 'GET' };
    idempotency(req, {}, () => calls.push('next'));
    assert.equal(calls.length, 1);
  });

  it('calls next() for POST with Idempotency-Key (first time)', () => {
    const calls = [];
    const req = { headers: { 'idempotency-key': 'key_new_' + Date.now() }, method: 'POST', userId: 'user_1' };
    const res = { statusCode: 200, json: (body) => body };
    idempotency(req, res, () => calls.push('next'));
    assert.equal(calls.length, 1);
  });

  it('returns cached response for duplicate key', () => {
    const key = 'key_dup_' + Date.now();
    const userId = 'user_dup';
    const req = { headers: { 'idempotency-key': key }, method: 'POST', userId };
    const res = {
      statusCode: 200,
      json: (body) => body,
    };

    // First call - processes normally
    idempotency(req, res, () => {});
    res.json({ success: true, data: { id: 'order_1' } });

    // Second call - should return cached
    let cachedBody;
    const req2 = { headers: { 'idempotency-key': key }, method: 'POST', userId };
    const res2 = {
      status: () => ({ json: (body) => { cachedBody = body; } }),
    };
    idempotency(req2, res2, () => { throw new Error('should not call next'); });

    assert.deepEqual(cachedBody, { success: true, data: { id: 'order_1' } });
  });

  it('does not cache error responses', () => {
    const key = 'key_err_' + Date.now();
    const userId = 'user_err';
    const req = { headers: { 'idempotency-key': key }, method: 'POST', userId };
    const res = {
      statusCode: 400,
      json: (body) => body,
    };

    // First call - error response
    idempotency(req, res, () => {});
    res.json({ success: false, error: { code: '40001' } });

    // Second call - should NOT return cached
    const calls = [];
    const req2 = { headers: { 'idempotency-key': key }, method: 'POST', userId };
    const res2 = { statusCode: 200, json: (body) => body };
    idempotency(req2, res2, () => calls.push('next'));

    assert.equal(calls.length, 1, 'should call next for non-cached error');
  });

  it('uses anonymous userId when not authenticated', () => {
    const key = 'key_anon_' + Date.now();
    const req = { headers: { 'idempotency-key': key }, method: 'POST' };
    const res = {
      statusCode: 200,
      json: (body) => body,
    };

    idempotency(req, res, () => {});
    res.json({ success: true });

    // Second call with same key, no userId
    let cachedBody;
    const req2 = { headers: { 'idempotency-key': key }, method: 'POST' };
    const res2 = {
      status: () => ({ json: (body) => { cachedBody = body; } }),
    };
    idempotency(req2, res2, () => {});

    assert.deepEqual(cachedBody, { success: true });
  });
});

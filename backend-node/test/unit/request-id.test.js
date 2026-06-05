const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { requestIdMiddleware } = require('../../src/middleware/request-id');

describe('Request ID middleware', () => {
  it('generates request ID with req_ prefix', () => {
    const req = { headers: {} };
    const res = { setHeader: () => {} };
    requestIdMiddleware(req, res, () => {});
    assert.ok(req.requestId.startsWith('req_'), 'should start with req_');
  });

  it('uses provided X-Request-Id header', () => {
    const req = { headers: { 'x-request-id': 'custom_id_123' } };
    const res = { setHeader: () => {} };
    requestIdMiddleware(req, res, () => {});
    assert.equal(req.requestId, 'custom_id_123');
  });

  it('sets X-Request-Id response header', () => {
    const req = { headers: {} };
    let headerName, headerValue;
    const res = { setHeader: (name, value) => { headerName = name; headerValue = value; } };
    requestIdMiddleware(req, res, () => {});
    assert.equal(headerName, 'X-Request-Id');
    assert.ok(headerValue.startsWith('req_'));
  });

  it('generates unique IDs', () => {
    const ids = new Set();
    for (let i = 0; i < 100; i++) {
      const req = { headers: {} };
      const res = { setHeader: () => {} };
      requestIdMiddleware(req, res, () => {});
      ids.add(req.requestId);
    }
    assert.equal(ids.size, 100, 'should generate 100 unique IDs');
  });

  it('calls next()', () => {
    const calls = [];
    const req = { headers: {} };
    const res = { setHeader: () => {} };
    requestIdMiddleware(req, res, () => calls.push('next'));
    assert.equal(calls.length, 1);
  });

  it('request ID has sufficient length', () => {
    const req = { headers: {} };
    const res = { setHeader: () => {} };
    requestIdMiddleware(req, res, () => {});
    assert.ok(req.requestId.length >= 10, `ID should be at least 10 chars, got ${req.requestId.length}`);
  });
});

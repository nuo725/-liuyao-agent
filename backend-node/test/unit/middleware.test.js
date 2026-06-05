const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { z } = require('zod');
const { validate } = require('../../src/middleware/validate');
const { requestIdMiddleware } = require('../../src/middleware/request-id');

describe('Middleware modules', () => {
  describe('validate()', () => {
    it('calls next() when validation passes', () => {
      const schema = z.object({ name: z.string() });
      const calls = [];
      const req = { body: { name: 'test' } };
      const middleware = validate(schema, 'body');
      middleware(req, {}, () => calls.push('next'));
      assert.equal(calls.length, 1);
      assert.equal(calls[0], 'next');
    });

    it('sets req.validated with parsed data', () => {
      const schema = z.object({ name: z.string() });
      const req = { body: { name: 'test' } };
      validate(schema, 'body')(req, {}, () => {});
      assert.equal(req.validated.body.name, 'test');
    });

    it('throws ApiError when validation fails', () => {
      const schema = z.object({ name: z.string() });
      const req = { body: { name: 123 } }; // name should be string
      assert.throws(
        () => validate(schema, 'body')(req, {}, () => {}),
        /Expected string/
      );
    });

    it('validates query parameters', () => {
      const schema = z.object({ page: z.coerce.number() });
      const req = { query: { page: '1' } };
      validate(schema, 'query')(req, {}, () => {});
      assert.equal(req.validated.query.page, 1);
    });

    it('validates route params', () => {
      const schema = z.object({ id: z.string() });
      const req = { params: { id: 'user_123' } };
      validate(schema, 'params')(req, {}, () => {});
      assert.equal(req.validated.params.id, 'user_123');
    });

    it('creates validated object if not exists', () => {
      const schema = z.object({ name: z.string() });
      const req = { body: { name: 'test' } };
      validate(schema, 'body')(req, {}, () => {});
      assert.ok(req.validated);
      assert.ok(req.validated.body);
    });

    it('preserves existing validated fields', () => {
      const schema = z.object({ name: z.string() });
      const req = { body: { name: 'test' }, validated: { query: { page: 1 } } };
      validate(schema, 'body')(req, {}, () => {});
      assert.equal(req.validated.body.name, 'test');
      assert.equal(req.validated.query.page, 1);
    });
  });

  describe('requestIdMiddleware()', () => {
    it('generates request ID when not provided', () => {
      const req = { headers: {} };
      const res = { setHeader: () => {} };
      const calls = [];
      requestIdMiddleware(req, res, () => calls.push('next'));
      assert.ok(req.requestId, 'should set requestId');
      assert.ok(req.requestId.startsWith('req_'), 'should start with req_');
      assert.equal(calls.length, 1);
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

    it('generates unique IDs for different requests', () => {
      const ids = new Set();
      for (let i = 0; i < 10; i++) {
        const req = { headers: {} };
        const res = { setHeader: () => {} };
        requestIdMiddleware(req, res, () => {});
        ids.add(req.requestId);
      }
      assert.equal(ids.size, 10, 'should generate unique IDs');
    });

    it('request ID has correct format', () => {
      const req = { headers: {} };
      const res = { setHeader: () => {} };
      requestIdMiddleware(req, res, () => {});
      assert.ok(req.requestId.startsWith('req_'), 'should start with req_');
      assert.ok(req.requestId.length > 4, 'should have content after req_');
    });
  });
});

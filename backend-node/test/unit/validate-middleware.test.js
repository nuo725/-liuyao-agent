const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { z } = require('zod');
const { validate } = require('../../src/middleware/validate');

describe('Validate middleware', () => {
  describe('Body validation', () => {
    it('calls next() when body is valid', () => {
      const schema = z.object({ name: z.string(), age: z.number() });
      const calls = [];
      const req = { body: { name: 'test', age: 25 } };
      validate(schema, 'body')(req, {}, () => calls.push('next'));
      assert.equal(calls.length, 1);
    });

    it('sets req.validated.body with parsed data', () => {
      const schema = z.object({ name: z.string() });
      const req = { body: { name: 'hello' } };
      validate(schema, 'body')(req, {}, () => {});
      assert.equal(req.validated.body.name, 'hello');
    });

    it('throws when body is invalid', () => {
      const schema = z.object({ name: z.string() });
      const req = { body: { name: 123 } };
      assert.throws(
        () => validate(schema, 'body')(req, {}, () => {}),
        /Expected string/
      );
    });

    it('throws when required field is missing', () => {
      const schema = z.object({ name: z.string(), email: z.string() });
      const req = { body: { name: 'test' } };
      assert.throws(
        () => validate(schema, 'body')(req, {}, () => {}),
        /Required/
      );
    });
  });

  describe('Query validation', () => {
    it('validates query parameters', () => {
      const schema = z.object({ page: z.coerce.number(), pageSize: z.coerce.number() });
      const req = { query: { page: '1', pageSize: '20' } };
      validate(schema, 'query')(req, {}, () => {});
      assert.equal(req.validated.query.page, 1);
      assert.equal(req.validated.query.pageSize, 20);
    });

    it('throws when query is invalid', () => {
      const schema = z.object({ page: z.coerce.number() });
      const req = { query: { page: 'abc' } };
      assert.throws(
        () => validate(schema, 'query')(req, {}, () => {}),
        /Expected/
      );
    });
  });

  describe('Params validation', () => {
    it('validates route params', () => {
      const schema = z.object({ id: z.string().uuid() });
      const req = { params: { id: '550e8400-e29b-41d4-a716-446655440000' } };
      validate(schema, 'params')(req, {}, () => {});
      assert.equal(req.validated.params.id, '550e8400-e29b-41d4-a716-446655440000');
    });
  });

  describe('Validated object management', () => {
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
});

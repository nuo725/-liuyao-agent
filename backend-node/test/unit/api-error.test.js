const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { ApiError } = require('../../src/shared/api-error');

describe('ApiError module', () => {
  describe('Constructor', () => {
    it('creates error with code, message, and statusCode', () => {
      const err = new ApiError('40001', 'Bad request', 400);
      assert.equal(err.code, '40001');
      assert.equal(err.message, 'Bad request');
      assert.equal(err.statusCode, 400);
      assert.ok(err instanceof Error);
    });

    it('creates error with details', () => {
      const err = new ApiError('40001', 'Bad request', 400, { field: 'phone' });
      assert.deepEqual(err.details, { field: 'phone' });
    });

    it('defaults details to null', () => {
      const err = new ApiError('40001', 'Bad request', 400);
      assert.equal(err.details, null);
    });
  });

  describe('Static factory methods', () => {
    it('badRequest creates 400 error with code 40001', () => {
      const err = ApiError.badRequest();
      assert.equal(err.code, '40001');
      assert.equal(err.statusCode, 400);
      assert.equal(err.message, 'Invalid request payload');
    });

    it('badRequest accepts custom message', () => {
      const err = ApiError.badRequest('Custom message');
      assert.equal(err.message, 'Custom message');
    });

    it('badRequest accepts details', () => {
      const err = ApiError.badRequest('Invalid', { field: 'email' });
      assert.deepEqual(err.details, { field: 'email' });
    });

    it('unauthorized creates 401 error with code 40101', () => {
      const err = ApiError.unauthorized();
      assert.equal(err.code, '40101');
      assert.equal(err.statusCode, 401);
      assert.equal(err.message, 'Authentication required');
    });

    it('sessionExpired creates 401 error with code 40102', () => {
      const err = ApiError.sessionExpired();
      assert.equal(err.code, '40102');
      assert.equal(err.statusCode, 401);
      assert.equal(err.message, 'Session expired');
    });

    it('forbidden creates 403 error with code 40301', () => {
      const err = ApiError.forbidden();
      assert.equal(err.code, '40301');
      assert.equal(err.statusCode, 403);
      assert.equal(err.message, 'Permission denied');
    });

    it('notFound creates 404 error with code 40401', () => {
      const err = ApiError.notFound();
      assert.equal(err.code, '40401');
      assert.equal(err.statusCode, 404);
      assert.equal(err.message, 'Resource not found');
    });

    it('conflict creates 409 error with code 40901', () => {
      const err = ApiError.conflict();
      assert.equal(err.code, '40901');
      assert.equal(err.statusCode, 409);
      assert.equal(err.message, 'Invalid state transition');
    });

    it('rateLimited creates 429 error with code 42901', () => {
      const err = ApiError.rateLimited();
      assert.equal(err.code, '42901');
      assert.equal(err.statusCode, 429);
      assert.equal(err.message, 'Rate limit exceeded');
    });

    it('internal creates 500 error with code 50000', () => {
      const err = ApiError.internal();
      assert.equal(err.code, '50000');
      assert.equal(err.statusCode, 500);
      assert.equal(err.message, 'Internal server error');
    });

    it('timeout creates 504 error with code 50401', () => {
      const err = ApiError.timeout();
      assert.equal(err.code, '50401');
      assert.equal(err.statusCode, 504);
      assert.equal(err.message, 'Upstream timeout');
    });
  });

  describe('Error code consistency', () => {
    it('all error codes are 5-digit strings', () => {
      const codes = [
        ApiError.badRequest().code,
        ApiError.unauthorized().code,
        ApiError.sessionExpired().code,
        ApiError.forbidden().code,
        ApiError.notFound().code,
        ApiError.conflict().code,
        ApiError.rateLimited().code,
        ApiError.internal().code,
        ApiError.timeout().code,
      ];
      for (const code of codes) {
        assert.ok(/^\d{5}$/.test(code), `code ${code} should be 5-digit string`);
      }
    });

    it('error codes match HTTP status code prefix', () => {
      assert.ok(ApiError.badRequest().code.startsWith('4'), '400 errors start with 4');
      assert.ok(ApiError.unauthorized().code.startsWith('4'), '401 errors start with 4');
      assert.ok(ApiError.forbidden().code.startsWith('4'), '403 errors start with 4');
      assert.ok(ApiError.notFound().code.startsWith('4'), '404 errors start with 4');
      assert.ok(ApiError.internal().code.startsWith('5'), '500 errors start with 5');
      assert.ok(ApiError.timeout().code.startsWith('5'), '504 errors start with 5');
    });
  });

  describe('Custom messages', () => {
    it('all factories accept custom messages', () => {
      const customs = [
        ApiError.badRequest('custom'),
        ApiError.unauthorized('custom'),
        ApiError.sessionExpired('custom'),
        ApiError.forbidden('custom'),
        ApiError.notFound('custom'),
        ApiError.conflict('custom'),
        ApiError.rateLimited('custom'),
        ApiError.internal('custom'),
        ApiError.timeout('custom'),
      ];
      for (const err of customs) {
        assert.equal(err.message, 'custom');
      }
    });
  });
});

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { ApiError } = require('../../src/shared/api-error');
const { errorHandler } = require('../../src/middleware/error-handler');

describe('Error handler middleware', () => {
  it('handles ApiError with correct status and envelope', () => {
    let statusCode, body;
    const err = ApiError.badRequest('Invalid phone');
    const req = { requestId: 'req_test_1' };
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (b) => { body = b; },
    };

    errorHandler(err, req, res, () => {});

    assert.equal(statusCode, 400);
    assert.equal(body.success, false);
    assert.equal(body.error.code, '40001');
    assert.equal(body.error.message, 'Invalid phone');
    assert.equal(body.requestId, 'req_test_1');
  });

  it('handles unauthorized error', () => {
    let statusCode, body;
    const err = ApiError.unauthorized();
    const req = { requestId: 'req_test_2' };
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (b) => { body = b; },
    };

    errorHandler(err, req, res, () => {});

    assert.equal(statusCode, 401);
    assert.equal(body.error.code, '40101');
  });

  it('handles not found error', () => {
    let statusCode, body;
    const err = ApiError.notFound('User not found');
    const req = { requestId: 'req_test_3' };
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (b) => { body = b; },
    };

    errorHandler(err, req, res, () => {});

    assert.equal(statusCode, 404);
    assert.equal(body.error.code, '40401');
    assert.equal(body.error.message, 'User not found');
  });

  it('handles forbidden error', () => {
    let statusCode, body;
    const err = ApiError.forbidden();
    const req = { requestId: 'req_test_4' };
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (b) => { body = b; },
    };

    errorHandler(err, req, res, () => {});

    assert.equal(statusCode, 403);
    assert.equal(body.error.code, '40301');
  });

  it('handles conflict error', () => {
    let statusCode, body;
    const err = ApiError.conflict('Already joined');
    const req = { requestId: 'req_test_5' };
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (b) => { body = b; },
    };

    errorHandler(err, req, res, () => {});

    assert.equal(statusCode, 409);
    assert.equal(body.error.code, '40901');
  });

  it('handles rate limited error', () => {
    let statusCode, body;
    const err = ApiError.rateLimited();
    const req = { requestId: 'req_test_6' };
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (b) => { body = b; },
    };

    errorHandler(err, req, res, () => {});

    assert.equal(statusCode, 429);
    assert.equal(body.error.code, '42901');
  });

  it('handles unexpected errors as 500', () => {
    let statusCode, body;
    const err = new Error('Something broke');
    const req = { requestId: 'req_test_7' };
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (b) => { body = b; },
    };

    errorHandler(err, req, res, () => {});

    assert.equal(statusCode, 500);
    assert.equal(body.success, false);
    assert.equal(body.error.code, '50000');
    assert.equal(body.error.message, 'Internal server error');
    assert.equal(body.requestId, 'req_test_7');
  });

  it('always includes requestId in response', () => {
    const err = ApiError.badRequest();
    const req = { requestId: 'req_unique_123' };
    let body;
    const res = {
      status: () => res,
      json: (b) => { body = b; },
    };

    errorHandler(err, req, res, () => {});
    assert.equal(body.requestId, 'req_unique_123');
  });
});

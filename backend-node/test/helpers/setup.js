// Test Setup Helper
// Provides shared utilities for all test suites.

const { createApp } = require('../../src/app');

/**
 * Create a test app instance without starting the server.
 * Each test file should call this to get an isolated app.
 */
function createTestApp() {
  return createApp();
}

/**
 * Generate a unique test user identifier.
 */
function testUserId() {
  return `test_user_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}

/**
 * Generate a Bearer authorization header value with a fake JWT.
 * For integration tests that don't need real JWT verification.
 */
function fakeAuthHeader(userId = 'test_user') {
  // This is a placeholder; real integration tests should use
  // the auth module to obtain a valid token.
  return `Bearer fake_token_${userId}`;
}

/**
 * Standard response envelope assertion helpers.
 */
function assertOkEnvelope(t, body) {
  t.assert(body.success === true, `expected success=true, got ${body.success}`);
  t.assert(body.data !== undefined, 'expected data field');
}

function assertFailEnvelope(t, body, expectedCode) {
  t.assert(body.success === false, `expected success=false, got ${body.success}`);
  t.assert(body.error !== undefined, 'expected error field');
  if (expectedCode) {
    t.assert(
      body.error.code === expectedCode,
      `expected error code ${expectedCode}, got ${body.error.code}`
    );
  }
}

/**
 * Assert that a response has the standard requestId field.
 */
function assertRequestId(t, body) {
  t.assert(
    typeof body.requestId === 'string' && body.requestId.length > 0,
    'expected requestId in response'
  );
}

module.exports = {
  createTestApp,
  testUserId,
  fakeAuthHeader,
  assertOkEnvelope,
  assertFailEnvelope,
  assertRequestId,
};

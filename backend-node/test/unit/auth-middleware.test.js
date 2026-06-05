const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');

// Set up test environment before requiring auth module
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_for_auth_middleware_32_chars';
process.env.JWT_ACCESS_TTL = '7200';
process.env.JWT_REFRESH_TTL = '2592000';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';

const { requireAuth, optionalAuth, generateTokens, DEMO_USER_ID } = require('../../src/middleware/auth');

function signToken(userId = 'user_test', options = {}) {
  return jwt.sign({ sub: userId }, process.env.JWT_SECRET, options);
}

describe('Auth middleware', () => {
  describe('requireAuth()', () => {
    it('sets userId from valid token', () => {
      const token = signToken('user_123');
      const req = { headers: { authorization: `Bearer ${token}` } };
      let nextCalled = false;
      requireAuth(req, {}, () => { nextCalled = true; });
      assert.equal(nextCalled, true);
      assert.equal(req.userId, 'user_123');
    });

    it('sets authPayload from valid token', () => {
      const token = signToken('user_456');
      const req = { headers: { authorization: `Bearer ${token}` } };
      requireAuth(req, {}, () => {});
      assert.ok(req.authPayload);
      assert.equal(req.authPayload.sub, 'user_456');
    });

    it('throws 40101 when no Authorization header', () => {
      const req = { headers: {} };
      assert.throws(
        () => requireAuth(req, {}, () => {}),
        /Authentication required/
      );
    });

    it('throws 40101 when Authorization header is empty', () => {
      const req = { headers: { authorization: '' } };
      assert.throws(
        () => requireAuth(req, {}, () => {}),
        /Authentication required/
      );
    });

    it('throws 40102 when token is expired', () => {
      const token = signToken('user_expired', { expiresIn: '-1s' });
      const req = { headers: { authorization: `Bearer ${token}` } };
      assert.throws(
        () => requireAuth(req, {}, () => {}),
        /Session expired/
      );
    });

    it('throws 40102 when token is invalid', () => {
      const req = { headers: { authorization: 'Bearer invalid_token_here' } };
      assert.throws(
        () => requireAuth(req, {}, () => {}),
        /Session expired/
      );
    });

    it('throws 40101 when Bearer prefix is missing', () => {
      const token = signToken('user_1');
      const req = { headers: { authorization: token } };
      assert.throws(
        () => requireAuth(req, {}, () => {}),
        /Authentication required/
      );
    });
  });

  describe('optionalAuth()', () => {
    it('sets userId from valid token', () => {
      const token = signToken('user_opt');
      const req = { headers: { authorization: `Bearer ${token}` } };
      optionalAuth(req, {}, () => {});
      assert.equal(req.userId, 'user_opt');
    });

    it('falls back to demo user when no token', () => {
      const req = { headers: {} };
      optionalAuth(req, {}, () => {});
      assert.equal(req.userId, DEMO_USER_ID);
    });

    it('falls back to demo user when token is invalid', () => {
      const req = { headers: { authorization: 'Bearer invalid' } };
      optionalAuth(req, {}, () => {});
      assert.equal(req.userId, DEMO_USER_ID);
    });

    it('falls back to demo user when token is expired', () => {
      const token = signToken('user_exp', { expiresIn: '-1s' });
      const req = { headers: { authorization: `Bearer ${token}` } };
      optionalAuth(req, {}, () => {});
      assert.equal(req.userId, DEMO_USER_ID);
    });

    it('sets authPayload when token is valid', () => {
      const token = signToken('user_payload');
      const req = { headers: { authorization: `Bearer ${token}` } };
      optionalAuth(req, {}, () => {});
      assert.ok(req.authPayload);
      assert.equal(req.authPayload.sub, 'user_payload');
    });
  });

  describe('generateTokens()', () => {
    it('generates access and refresh tokens', () => {
      const tokens = generateTokens('user_gen');
      assert.ok(tokens.accessToken);
      assert.ok(tokens.refreshToken);
      assert.ok(tokens.expiresAt);
      assert.ok(tokens.refreshExpiresAt);
    });

    it('access token contains userId', () => {
      const tokens = generateTokens('user_verify');
      const payload = jwt.verify(tokens.accessToken, process.env.JWT_SECRET);
      assert.equal(payload.sub, 'user_verify');
    });

    it('refresh token contains userId and type', () => {
      const tokens = generateTokens('user_refresh');
      const payload = jwt.verify(tokens.refreshToken, process.env.JWT_SECRET);
      assert.equal(payload.sub, 'user_refresh');
      assert.equal(payload.type, 'refresh');
    });

    it('expiresAt is in the future', () => {
      const tokens = generateTokens('user_future');
      const expiresAt = new Date(tokens.expiresAt);
      assert.ok(expiresAt > new Date(), 'expiresAt should be in the future');
    });

    it('refreshExpiresAt is after expiresAt', () => {
      const tokens = generateTokens('user_order');
      const expiresAt = new Date(tokens.expiresAt);
      const refreshExpiresAt = new Date(tokens.refreshExpiresAt);
      assert.ok(refreshExpiresAt > expiresAt, 'refresh should expire after access');
    });
  });

  describe('DEMO_USER_ID', () => {
    it('is user_demo', () => {
      assert.equal(DEMO_USER_ID, 'user_demo');
    });
  });
});

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { consumeMemoryBucket, getIdentifier } = require('../../src/middleware/rate-limit');

describe('Rate limit middleware helpers', () => {
  it('tracks remaining requests and blocks after the limit', () => {
    const store = new Map();
    const now = Date.parse('2026-06-05T00:00:00.000Z');

    const first = consumeMemoryBucket(store, 'ip:127.0.0.1', 'send-code', 2, 60, now);
    const second = consumeMemoryBucket(store, 'ip:127.0.0.1', 'send-code', 2, 60, now + 1000);

    assert.equal(first.remaining, 1);
    assert.equal(second.remaining, 0);
    assert.throws(
      () => consumeMemoryBucket(store, 'ip:127.0.0.1', 'send-code', 2, 60, now + 2000),
      /Rate limit exceeded/,
    );
  });

  it('resets after the window expires', () => {
    const store = new Map();
    const now = Date.parse('2026-06-05T00:00:00.000Z');

    consumeMemoryBucket(store, 'ip:127.0.0.1', 'phone-login', 1, 60, now);
    const reset = consumeMemoryBucket(store, 'ip:127.0.0.1', 'phone-login', 1, 60, now + 61_000);

    assert.equal(reset.count, 1);
    assert.equal(reset.remaining, 0);
  });

  it('prefers authenticated user id over IP address', () => {
    const identifier = getIdentifier({
      userId: 'user_123',
      ip: '127.0.0.1',
      headers: {},
    });

    assert.equal(identifier, 'user:user_123');
  });

  it('uses x-forwarded-for for anonymous requests', () => {
    const identifier = getIdentifier({
      headers: { 'x-forwarded-for': '203.0.113.8, 10.0.0.1' },
      ip: '127.0.0.1',
    });

    assert.equal(identifier, 'ip:203.0.113.8');
  });
});

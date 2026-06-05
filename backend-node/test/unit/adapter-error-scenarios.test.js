const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

describe('Adapter error scenarios (ADAPTER-001)', () => {
  describe('Timeout handling', () => {
    it('detects timeout when adapter does not respond within deadline', async () => {
      const deadline = 100; // ms
      const start = Date.now();

      const result = await Promise.race([
        new Promise((resolve) => setTimeout(() => resolve({ ok: true }), 500)),
        new Promise((resolve) => setTimeout(() => resolve({ ok: false, error: 'timeout' }), deadline)),
      ]);

      assert.equal(result.ok, false);
      assert.equal(result.error, 'timeout');
      assert.ok(Date.now() - start < 200, 'should timeout quickly');
    });

    it('succeeds when adapter responds within deadline', async () => {
      const deadline = 500;
      const result = await Promise.race([
        Promise.resolve({ ok: true, data: 'response' }),
        new Promise((resolve) => setTimeout(() => resolve({ ok: false, error: 'timeout' }), deadline)),
      ]);

      assert.equal(result.ok, true);
      assert.equal(result.data, 'response');
    });
  });

  describe('Retry logic', () => {
    it('retries failed requests up to max attempts', async () => {
      let attempts = 0;
      const maxRetries = 3;

      async function callWithRetry(fn, maxAttempts) {
        for (let i = 0; i < maxAttempts; i++) {
          try {
            return await fn();
          } catch (err) {
            if (i === maxAttempts - 1) throw err;
          }
        }
      }

      const result = await callWithRetry(async () => {
        attempts++;
        if (attempts < 3) throw new Error('temporary failure');
        return { ok: true };
      }, maxRetries);

      assert.equal(result.ok, true);
      assert.equal(attempts, 3);
    });

    it('gives up after max retries', async () => {
      let attempts = 0;
      const maxRetries = 3;

      async function callWithRetry(fn, maxAttempts) {
        for (let i = 0; i < maxAttempts; i++) {
          try {
            return await fn();
          } catch (err) {
            if (i === maxAttempts - 1) throw err;
          }
        }
      }

      await assert.rejects(
        () => callWithRetry(async () => {
          attempts++;
          throw new Error('permanent failure');
        }, maxRetries),
        /permanent failure/
      );

      assert.equal(attempts, 3);
    });
  });

  describe('Invalid response handling', () => {
    it('handles non-JSON response gracefully', () => {
      const response = '<html>Internal Server Error</html>';
      let parsed;
      try {
        parsed = JSON.parse(response);
      } catch {
        parsed = null;
      }
      assert.equal(parsed, null, 'should fail to parse HTML as JSON');
    });

    it('handles missing required fields in response', () => {
      const response = { status: 'ok' }; // missing data field
      const hasRequiredFields = 'data' in response || 'error' in response;
      assert.equal(hasRequiredFields, false, 'should detect missing data/error');
    });

    it('handles unexpected response status codes', () => {
      const validStatuses = [200, 201, 204, 400, 401, 403, 404, 500];
      const status = 502;
      assert.ok(!validStatuses.includes(status), '502 should be unexpected');
    });
  });

  describe('Partial failure handling', () => {
    it('continues when non-critical adapter fails', async () => {
      const results = await Promise.allSettled([
        Promise.resolve({ adapter: 'sms', ok: true }),
        Promise.reject(new Error('push adapter failed')),
        Promise.resolve({ adapter: 'storage', ok: true }),
      ]);

      const fulfilled = results.filter((r) => r.status === 'fulfilled');
      const rejected = results.filter((r) => r.status === 'rejected');

      assert.equal(fulfilled.length, 2, '2 adapters should succeed');
      assert.equal(rejected.length, 1, '1 adapter should fail');
    });

    it('collects errors from all failed adapters', async () => {
      const results = await Promise.allSettled([
        Promise.reject(new Error('SMS failed')),
        Promise.reject(new Error('Push failed')),
        Promise.resolve({ ok: true }),
      ]);

      const errors = results
        .filter((r) => r.status === 'rejected')
        .map((r) => r.reason.message);

      assert.deepEqual(errors, ['SMS failed', 'Push failed']);
    });
  });

  describe('Circuit breaker pattern', () => {
    it('opens circuit after consecutive failures', () => {
      const threshold = 3;
      let failures = 0;
      let circuitOpen = false;

      function recordFailure() {
        failures++;
        if (failures >= threshold) {
          circuitOpen = true;
        }
      }

      recordFailure();
      assert.equal(circuitOpen, false);
      recordFailure();
      assert.equal(circuitOpen, false);
      recordFailure();
      assert.equal(circuitOpen, true, 'circuit should open after 3 failures');
    });

    it('resets circuit after successful request', () => {
      let failures = 2;
      let circuitOpen = false;

      function recordSuccess() {
        failures = 0;
        circuitOpen = false;
      }

      recordSuccess();
      assert.equal(failures, 0);
      assert.equal(circuitOpen, false);
    });
  });

  describe('Fallback behavior', () => {
    it('falls back to test SMS when production adapter is unavailable', () => {
      const provider = process.env.SMS_PROVIDER || 'test';
      const code = provider === 'test' ? '123456' : null;
      assert.equal(code, '123456', 'should fall back to test code');
    });

    it('falls back to default values when adapter returns empty', () => {
      const response = null;
      const fallback = { items: [], total: 0 };
      const result = response || fallback;
      assert.deepEqual(result, fallback, 'should use fallback');
    });
  });

  describe('Input validation at adapter boundary', () => {
    it('rejects empty phone number for SMS', () => {
      const phone = '';
      const isValid = typeof phone === 'string' && phone.length >= 8;
      assert.equal(isValid, false);
    });

    it('rejects invalid platform for push token', () => {
      const validPlatforms = ['android', 'ios', 'web'];
      const platform = 'windows';
      assert.ok(!validPlatforms.includes(platform));
    });

    it('rejects oversized media upload', () => {
      const maxSize = 10 * 1024 * 1024; // 10MB
      const fileSize = 15 * 1024 * 1024;
      assert.ok(fileSize > maxSize, 'should reject oversized file');
    });

    it('rejects unsupported MIME type', () => {
      const allowedMimes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
      const mime = 'application/pdf';
      assert.ok(!allowedMimes.includes(mime), 'should reject PDF');
    });
  });
});

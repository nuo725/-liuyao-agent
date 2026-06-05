const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { evaluateAlerts, buildAlertPayload, parseAlertArgs, runAlertCheck } = require('../../scripts/alert-check');
const { recordRequest, resetMetrics, snapshotMetrics } = require('../../src/shared/monitoring');

describe('Monitoring metrics', () => {
  beforeEach(() => {
    resetMetrics();
  });

  it('records request counts, errors, and durations', () => {
    recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 12.2 });
    recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 503, durationMs: 30 });

    const snapshot = snapshotMetrics();
    assert.equal(snapshot.requests, 2);
    assert.equal(snapshot.errors, 1);
    assert.equal(snapshot.errorRate, 0.5);
    assert.equal(snapshot.routes[0].count, 2);
    assert.equal(snapshot.routes[0].errors, 1);
  });
});

describe('Alert evaluation', () => {
  it('flags readiness, error rate, and latency alerts', () => {
    const alerts = evaluateAlerts({
      ready: false,
      metrics: { errorRate: 0.2, avgDurationMs: 1500 },
      maxErrorRate: 0.05,
      maxAvgDurationMs: 1000,
    });

    assert.deepEqual(alerts.map((alert) => alert.code), [
      'not_ready',
      'error_rate_high',
      'latency_high',
    ]);
  });

  it('passes healthy metrics', () => {
    const alerts = evaluateAlerts({
      ready: true,
      metrics: { errorRate: 0.01, avgDurationMs: 80 },
      maxErrorRate: 0.05,
      maxAvgDurationMs: 1000,
    });

    assert.deepEqual(alerts, []);
  });

  it('flags only error rate when latency is within threshold', () => {
    const alerts = evaluateAlerts({
      ready: true,
      metrics: { errorRate: 0.15, avgDurationMs: 500 },
      maxErrorRate: 0.05,
      maxAvgDurationMs: 1000,
    });

    assert.equal(alerts.length, 1);
    assert.equal(alerts[0].code, 'error_rate_high');
  });

  it('handles missing metrics fields gracefully', () => {
    const alerts = evaluateAlerts({
      ready: true,
      metrics: {},
      maxErrorRate: 0.05,
      maxAvgDurationMs: 1000,
    });

    assert.deepEqual(alerts, []);
  });
});

describe('Alert payload', () => {
  it('builds a structured webhook payload', () => {
    const alerts = [{ code: 'not_ready', message: 'Readiness check is not healthy' }];
    const payload = buildAlertPayload({ baseUrl: 'http://localhost:3000', alerts });

    assert.equal(payload.title, 'zhouyi-backend alert');
    assert.equal(payload.baseUrl, 'http://localhost:3000');
    assert.deepEqual(payload.alerts, alerts);
    assert.ok(payload.checkedAt);
  });
});

describe('parseAlertArgs', () => {
  it('parses CLI arguments', () => {
    const result = parseAlertArgs([
      '--baseUrl=https://api.example.com',
      '--webhookUrl=https://hooks.example.com/alert',
      '--maxErrorRate=0.1',
      '--maxAvgDurationMs=2000',
      '--dry-run',
    ]);

    assert.equal(result.baseUrl, 'https://api.example.com');
    assert.equal(result.webhookUrl, 'https://hooks.example.com/alert');
    assert.equal(result.maxErrorRate, 0.1);
    assert.equal(result.maxAvgDurationMs, 2000);
    assert.equal(result.dryRun, true);
  });

  it('defaults when no args', () => {
    const result = parseAlertArgs([]);
    assert.equal(result.baseUrl, 'http://127.0.0.1:3000');
    assert.equal(result.webhookUrl, '');
    assert.equal(result.maxErrorRate, 0.05);
    assert.equal(result.maxAvgDurationMs, 1000);
    assert.equal(result.dryRun, false);
  });
});

describe('runAlertCheck', () => {
  it('returns ok=true when all checks pass', async () => {
    const mockFetch = async (_url) => ({
      status: 200,
      json: async () => ({ data: { ready: true, errorRate: 0.01, avgDurationMs: 100 } }),
    });

    const result = await runAlertCheck({
      baseUrl: 'http://localhost:3000',
      fetchFn: mockFetch,
    });

    assert.equal(result.ok, true);
    assert.deepEqual(result.alerts, []);
    assert.equal(result.webhookSent, false);
  });

  it('sends webhook when alerts fire and webhookUrl is set', async () => {
    const webhookCalls = [];
    const mockFetch = async (_url, options) => {
      if (_url.includes('hooks')) {
        webhookCalls.push({ url: _url, options });
        return { status: 200, json: async () => ({ ok: true }) };
      }
      return {
        status: 200,
        json: async () => ({ data: { ready: false, errorRate: 0.5, avgDurationMs: 3000 } }),
      };
    };

    const result = await runAlertCheck({
      baseUrl: 'http://localhost:3000',
      webhookUrl: 'https://hooks.example.com/alert',
      fetchFn: mockFetch,
    });

    assert.equal(result.ok, false);
    assert.equal(result.webhookSent, true);
    assert.equal(webhookCalls.length, 1);
    assert.equal(webhookCalls[0].url, 'https://hooks.example.com/alert');
    assert.equal(webhookCalls[0].options.method, 'POST');
  });

  it('does not send webhook in dry-run mode', async () => {
    const webhookCalls = [];
    const mockFetch = async (url, options) => {
      if (url.includes('hooks')) {
        webhookCalls.push({ url, options });
        return { status: 200, json: async () => ({ ok: true }) };
      }
      return {
        status: 200,
        json: async () => ({ data: { ready: false, errorRate: 0.5, avgDurationMs: 3000 } }),
      };
    };

    const result = await runAlertCheck({
      baseUrl: 'http://localhost:3000',
      webhookUrl: 'https://hooks.example.com/alert',
      dryRun: true,
      fetchFn: mockFetch,
    });

    assert.equal(result.ok, false);
    assert.equal(result.webhookSent, false);
    assert.equal(webhookCalls.length, 0);
  });
});

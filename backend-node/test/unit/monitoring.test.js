const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { evaluateAlerts } = require('../../scripts/alert-check');
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
});

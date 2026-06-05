const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { recordRequest, resetMetrics, snapshotMetrics } = require('../../src/shared/monitoring');
const { evaluateAlerts, buildAlertPayload } = require('../../scripts/alert-check');

describe('Monitoring validation (OPS-VERIFY-003)', () => {
  beforeEach(() => {
    resetMetrics();
  });

  describe('Metrics recording', () => {
    it('records single request correctly', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 42 });

      const snapshot = snapshotMetrics();
      assert.equal(snapshot.requests, 1);
      assert.equal(snapshot.errors, 0);
      assert.equal(snapshot.errorRate, 0);
      assert.ok(snapshot.avgDurationMs > 0, 'should have avg duration');
    });

    it('records multiple requests', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      recordRequest({ method: 'POST', path: '/api/v1/auth/login', statusCode: 200, durationMs: 50 });
      recordRequest({ method: 'GET', path: '/api/v1/profile/me', statusCode: 200, durationMs: 30 });

      const snapshot = snapshotMetrics();
      assert.equal(snapshot.requests, 3);
      assert.equal(snapshot.errors, 0);
    });

    it('tracks errors correctly', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      recordRequest({ method: 'GET', path: '/api/v1/missing', statusCode: 404, durationMs: 5 });
      recordRequest({ method: 'POST', path: '/api/v1/ritual/perform', statusCode: 500, durationMs: 100 });

      const snapshot = snapshotMetrics();
      assert.equal(snapshot.requests, 3);
      assert.equal(snapshot.errors, 1, 'only 5xx should count as error');
      assert.ok(snapshot.errorRate > 0, 'should have non-zero error rate');
    });

    it('tracks per-route metrics', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 20 });
      recordRequest({ method: 'POST', path: '/api/v1/auth/login', statusCode: 200, durationMs: 50 });

      const snapshot = snapshotMetrics();
      assert.ok(Array.isArray(snapshot.routes), 'should have routes array');
      assert.ok(snapshot.routes.length >= 2, 'should have at least 2 routes');

      const healthRoute = snapshot.routes.find((r) => r.path === '/api/v1/health');
      assert.ok(healthRoute, 'should have health route');
      assert.equal(healthRoute.count, 2, 'health should have 2 requests');
    });

    it('calculates average duration', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 100 });
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 200 });

      const snapshot = snapshotMetrics();
      assert.equal(snapshot.avgDurationMs, 150, 'avg should be 150');
    });
  });

  describe('Metrics reset', () => {
    it('resetMetrics clears all counters', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 500, durationMs: 100 });

      resetMetrics();
      const snapshot = snapshotMetrics();

      assert.equal(snapshot.requests, 0);
      assert.equal(snapshot.errors, 0);
      assert.equal(snapshot.routes.length, 0);
    });
  });

  describe('Alert rules', () => {
    it('triggers not_ready alert when health check fails', () => {
      const alerts = evaluateAlerts({
        ready: false,
        metrics: { errorRate: 0, avgDurationMs: 50 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });

      assert.equal(alerts.length, 1);
      assert.equal(alerts[0].code, 'not_ready');
    });

    it('triggers error_rate_high alert when error rate exceeds threshold', () => {
      const alerts = evaluateAlerts({
        ready: true,
        metrics: { errorRate: 0.1, avgDurationMs: 50 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });

      assert.equal(alerts.length, 1);
      assert.equal(alerts[0].code, 'error_rate_high');
    });

    it('triggers latency_high alert when avg duration exceeds threshold', () => {
      const alerts = evaluateAlerts({
        ready: true,
        metrics: { errorRate: 0.01, avgDurationMs: 2000 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });

      assert.equal(alerts.length, 1);
      assert.equal(alerts[0].code, 'latency_high');
    });

    it('triggers multiple alerts simultaneously', () => {
      const alerts = evaluateAlerts({
        ready: false,
        metrics: { errorRate: 0.5, avgDurationMs: 5000 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });

      assert.equal(alerts.length, 3);
      const codes = alerts.map((a) => a.code);
      assert.ok(codes.includes('not_ready'));
      assert.ok(codes.includes('error_rate_high'));
      assert.ok(codes.includes('latency_high'));
    });

    it('no alerts when all metrics are healthy', () => {
      const alerts = evaluateAlerts({
        ready: true,
        metrics: { errorRate: 0.01, avgDurationMs: 100 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });

      assert.equal(alerts.length, 0);
    });

    it('handles missing metrics fields gracefully', () => {
      const alerts = evaluateAlerts({
        ready: true,
        metrics: {},
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });

      assert.equal(alerts.length, 0, 'missing fields should not trigger alerts');
    });
  });

  describe('Alert payload', () => {
    it('builds valid webhook payload', () => {
      const alerts = [
        { code: 'not_ready', message: 'Readiness check is not healthy' },
        { code: 'error_rate_high', message: 'Error rate 0.5 is above 0.05' },
      ];

      const payload = buildAlertPayload({
        baseUrl: 'http://localhost:3000',
        alerts,
      });

      assert.equal(payload.title, 'zhouyi-backend alert');
      assert.equal(payload.baseUrl, 'http://localhost:3000');
      assert.deepEqual(payload.alerts, alerts);
      assert.ok(payload.checkedAt, 'should have timestamp');
      assert.ok(!isNaN(Date.parse(payload.checkedAt)), 'timestamp should be valid');
    });

    it('payload is JSON serializable', () => {
      const alerts = [{ code: 'test', message: 'test alert' }];
      const payload = buildAlertPayload({ baseUrl: 'http://localhost:3000', alerts });

      const json = JSON.stringify(payload);
      const parsed = JSON.parse(json);
      assert.equal(parsed.title, 'zhouyi-backend alert');
      assert.equal(parsed.alerts.length, 1);
    });
  });

  describe('Threshold configuration', () => {
    it('default thresholds are reasonable', () => {
      const defaultMaxErrorRate = 0.05;
      const defaultMaxAvgDurationMs = 1000;

      assert.ok(defaultMaxErrorRate > 0 && defaultMaxErrorRate < 1, 'error rate threshold should be between 0 and 1');
      assert.ok(defaultMaxAvgDurationMs > 0, 'duration threshold should be positive');
    });

    it('custom thresholds affect alert evaluation', () => {
      // With strict thresholds
      const strictAlerts = evaluateAlerts({
        ready: true,
        metrics: { errorRate: 0.02, avgDurationMs: 500 },
        maxErrorRate: 0.01,
        maxAvgDurationMs: 100,
      });

      assert.equal(strictAlerts.length, 2, 'strict thresholds should trigger 2 alerts');

      // With relaxed thresholds
      const relaxedAlerts = evaluateAlerts({
        ready: true,
        metrics: { errorRate: 0.02, avgDurationMs: 500 },
        maxErrorRate: 0.1,
        maxAvgDurationMs: 1000,
      });

      assert.equal(relaxedAlerts.length, 0, 'relaxed thresholds should trigger no alerts');
    });
  });
});

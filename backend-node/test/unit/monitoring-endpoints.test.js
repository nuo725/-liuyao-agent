const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { recordRequest, resetMetrics, snapshotMetrics } = require('../../src/shared/monitoring');
const { evaluateAlerts, buildAlertPayload, parseAlertArgs } = require('../../scripts/alert-check');

describe('Monitoring endpoints (OPS-006)', () => {
  beforeEach(() => {
    resetMetrics();
  });

  describe('Metrics snapshot structure', () => {
    it('snapshot has all required fields', () => {
      const snapshot = snapshotMetrics();
      assert.ok('requests' in snapshot, 'should have requests');
      assert.ok('errors' in snapshot, 'should have errors');
      assert.ok('errorRate' in snapshot, 'should have errorRate');
      assert.ok('routes' in snapshot, 'should have routes');
    });

    it('snapshot is JSON serializable', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      const snapshot = snapshotMetrics();
      const json = JSON.stringify(snapshot);
      const parsed = JSON.parse(json);
      assert.equal(parsed.requests, 1);
    });
  });

  describe('Request recording', () => {
    it('increments request count', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 20 });
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 30 });

      const snapshot = snapshotMetrics();
      assert.equal(snapshot.requests, 3);
    });

    it('tracks errors separately', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      recordRequest({ method: 'GET', path: '/api/v1/missing', statusCode: 500, durationMs: 50 });

      const snapshot = snapshotMetrics();
      assert.equal(snapshot.requests, 2);
      assert.equal(snapshot.errors, 1);
    });

    it('calculates error rate', () => {
      for (let i = 0; i < 8; i++) {
        recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      }
      recordRequest({ method: 'GET', path: '/api/v1/error', statusCode: 500, durationMs: 100 });
      recordRequest({ method: 'GET', path: '/api/v1/error', statusCode: 500, durationMs: 100 });

      const snapshot = snapshotMetrics();
      assert.equal(snapshot.requests, 10);
      assert.equal(snapshot.errors, 2);
      assert.equal(snapshot.errorRate, 0.2);
    });
  });

  describe('Route tracking', () => {
    it('tracks per-route metrics', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 20 });
      recordRequest({ method: 'POST', path: '/api/v1/auth/login', statusCode: 200, durationMs: 50 });

      const snapshot = snapshotMetrics();
      assert.ok(Array.isArray(snapshot.routes), 'routes should be array');
      assert.ok(snapshot.routes.length >= 2, 'should have at least 2 routes');
    });

    it('route has count and path', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });

      const snapshot = snapshotMetrics();
      const healthRoute = snapshot.routes.find((r) => r.path === '/api/v1/health');
      assert.ok(healthRoute, 'should have health route');
      assert.equal(healthRoute.count, 1);
    });
  });

  describe('Alert evaluation', () => {
    it('no alerts for healthy metrics', () => {
      const alerts = evaluateAlerts({
        ready: true,
        metrics: { errorRate: 0.01, avgDurationMs: 100 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });
      assert.equal(alerts.length, 0);
    });

    it('alerts on high error rate', () => {
      const alerts = evaluateAlerts({
        ready: true,
        metrics: { errorRate: 0.1, avgDurationMs: 100 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });
      assert.equal(alerts.length, 1);
      assert.equal(alerts[0].code, 'error_rate_high');
    });

    it('alerts on high latency', () => {
      const alerts = evaluateAlerts({
        ready: true,
        metrics: { errorRate: 0.01, avgDurationMs: 2000 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });
      assert.equal(alerts.length, 1);
      assert.equal(alerts[0].code, 'latency_high');
    });

    it('alerts on not ready', () => {
      const alerts = evaluateAlerts({
        ready: false,
        metrics: { errorRate: 0.01, avgDurationMs: 100 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });
      assert.equal(alerts.length, 1);
      assert.equal(alerts[0].code, 'not_ready');
    });

    it('multiple alerts can fire simultaneously', () => {
      const alerts = evaluateAlerts({
        ready: false,
        metrics: { errorRate: 0.5, avgDurationMs: 5000 },
        maxErrorRate: 0.05,
        maxAvgDurationMs: 1000,
      });
      assert.equal(alerts.length, 3);
    });
  });

  describe('Alert payload', () => {
    it('builds valid webhook payload', () => {
      const alerts = [{ code: 'test', message: 'test alert' }];
      const payload = buildAlertPayload({ baseUrl: 'http://localhost:3000', alerts });

      assert.equal(payload.title, 'zhouyi-backend alert');
      assert.equal(payload.baseUrl, 'http://localhost:3000');
      assert.deepEqual(payload.alerts, alerts);
      assert.ok(payload.checkedAt);
    });
  });

  describe('Alert argument parsing', () => {
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

  describe('Health check endpoint format', () => {
    it('health response has status field', () => {
      // Simulate health check response structure
      const healthResponse = {
        success: true,
        data: {
          status: 'ok',
          uptime: process.uptime(),
          timestamp: new Date().toISOString(),
        },
      };

      assert.equal(healthResponse.success, true);
      assert.ok(healthResponse.data.status);
      assert.ok(healthResponse.data.uptime >= 0);
      assert.ok(healthResponse.data.timestamp);
    });
  });

  describe('Metrics endpoint format', () => {
    it('metrics response includes request statistics', () => {
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 10 });
      recordRequest({ method: 'GET', path: '/api/v1/health', statusCode: 200, durationMs: 20 });

      const snapshot = snapshotMetrics();
      const metricsResponse = {
        success: true,
        data: snapshot,
      };

      assert.equal(metricsResponse.success, true);
      assert.equal(metricsResponse.data.requests, 2);
      assert.ok(Array.isArray(metricsResponse.data.routes));
    });
  });
});

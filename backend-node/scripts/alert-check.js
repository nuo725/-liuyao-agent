#!/usr/bin/env node

function evaluateAlerts({ ready, metrics, maxErrorRate, maxAvgDurationMs }) {
  const alerts = [];
  if (!ready) {
    alerts.push({ code: 'not_ready', message: 'Readiness check is not healthy' });
  }
  if ((metrics.errorRate || 0) > maxErrorRate) {
    alerts.push({
      code: 'error_rate_high',
      message: `Error rate ${metrics.errorRate} is above ${maxErrorRate}`,
    });
  }
  if ((metrics.avgDurationMs || 0) > maxAvgDurationMs) {
    alerts.push({
      code: 'latency_high',
      message: `Average duration ${metrics.avgDurationMs}ms is above ${maxAvgDurationMs}ms`,
    });
  }
  return alerts;
}

function buildAlertPayload({ baseUrl, alerts }) {
  return {
    title: 'zhouyi-backend alert',
    baseUrl,
    alerts,
    checkedAt: new Date().toISOString(),
  };
}

function parseAlertArgs(argv) {
  const values = Object.fromEntries(
    argv
      .filter((arg) => arg.startsWith('--') && arg.includes('='))
      .map((arg) => {
        const [key, ...rest] = arg.slice(2).split('=');
        return [key, rest.join('=')];
      }),
  );
  return {
    baseUrl: values.baseUrl || process.env.MONITOR_BASE_URL || 'http://127.0.0.1:3000',
    webhookUrl: values.webhookUrl || process.env.ALERT_WEBHOOK_URL || '',
    maxErrorRate: Number(values.maxErrorRate || process.env.ALERT_MAX_ERROR_RATE || 0.05),
    maxAvgDurationMs: Number(values.maxAvgDurationMs || process.env.ALERT_MAX_AVG_DURATION_MS || 1000),
    dryRun: argv.includes('--dry-run'),
  };
}

async function runAlertCheck({
  baseUrl = process.env.MONITOR_BASE_URL || 'http://127.0.0.1:3000',
  webhookUrl = process.env.ALERT_WEBHOOK_URL || '',
  maxErrorRate = Number(process.env.ALERT_MAX_ERROR_RATE || 0.05),
  maxAvgDurationMs = Number(process.env.ALERT_MAX_AVG_DURATION_MS || 1000),
  dryRun = false,
  fetchFn = fetch,
} = {}) {
  const health = await fetchJson(`${baseUrl}/api/v1/ready`, fetchFn);
  const metrics = await fetchJson(`${baseUrl}/api/v1/metrics`, fetchFn);
  const alerts = evaluateAlerts({
    ready: health.status < 500 && health.body?.data?.ready === true,
    metrics: metrics.body?.data || {},
    maxErrorRate,
    maxAvgDurationMs,
  });

  if (alerts.length > 0) {
    const payload = buildAlertPayload({ baseUrl, alerts });
    if (webhookUrl && !dryRun) {
      await fetchFn(webhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    }
    return { ok: false, alerts, webhookSent: Boolean(webhookUrl && !dryRun) };
  }

  return { ok: true, alerts: [], webhookSent: false };
}

async function fetchJson(url, fetchFn = fetch) {
  const response = await fetchFn(url);
  const body = await response.json();
  return { status: response.status, body };
}

if (require.main === module) {
  runAlertCheck(parseAlertArgs(process.argv.slice(2)))
    .then((result) => {
      console.log(JSON.stringify(result, null, 2));
      process.exit(result.ok ? 0 : 1);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = {
  evaluateAlerts,
  buildAlertPayload,
  parseAlertArgs,
  runAlertCheck,
};

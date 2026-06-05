#!/usr/bin/env node
/* global AbortController, clearTimeout */

const { performance } = require('perf_hooks');

async function runLoadTest({
  url,
  requests = 100,
  concurrency = 10,
  method = 'GET',
  headers = {},
  body,
  timeoutMs = 5000,
  maxP95Ms = 1000,
  maxErrorRate = 0.01,
}) {
  const results = [];
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < requests) {
      nextIndex += 1;
      results.push(await runOne({ url, method, headers, body, timeoutMs }));
    }
  }

  const workerCount = Math.min(concurrency, requests);
  await Promise.all(Array.from({ length: workerCount }, worker));
  const summary = summarizeResults(results);
  summary.passed = summary.p95Ms <= maxP95Ms && summary.errorRate <= maxErrorRate;
  summary.thresholds = { maxP95Ms, maxErrorRate };
  return summary;
}

async function runOne({ url, method, headers, body, timeoutMs }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const started = performance.now();
  try {
    const request = {
      method,
      headers,
      signal: controller.signal,
    };
    if (body !== undefined && !['GET', 'HEAD'].includes(method)) {
      request.body = typeof body === 'string' ? body : JSON.stringify(body);
      request.headers = {
        'Content-Type': 'application/json',
        ...headers,
      };
    }
    const response = await fetch(url, request);
    return {
      ok: response.status < 500,
      status: response.status,
      durationMs: performance.now() - started,
    };
  } catch (err) {
    return {
      ok: false,
      status: err.name === 'AbortError' ? 'timeout' : 'error',
      durationMs: performance.now() - started,
    };
  } finally {
    clearTimeout(timeout);
  }
}

function summarizeResults(results) {
  const durations = results.map((result) => result.durationMs).sort((a, b) => a - b);
  const failures = results.filter((result) => !result.ok).length;
  const total = results.length;
  const statusCodes = results.reduce((acc, result) => {
    acc[result.status] = (acc[result.status] || 0) + 1;
    return acc;
  }, {});

  return {
    total,
    failures,
    errorRate: total ? round(failures / total) : 0,
    minMs: round(durations[0] || 0),
    avgMs: round(durations.reduce((sum, value) => sum + value, 0) / (total || 1)),
    p50Ms: round(percentile(durations, 0.5)),
    p95Ms: round(percentile(durations, 0.95)),
    maxMs: round(durations[durations.length - 1] || 0),
    statusCodes,
  };
}

function percentile(sortedValues, p) {
  if (sortedValues.length === 0) return 0;
  const index = Math.ceil(sortedValues.length * p) - 1;
  return sortedValues[Math.max(0, Math.min(index, sortedValues.length - 1))];
}

function round(value) {
  return Math.round(value * 100) / 100;
}

function parseArgs(argv) {
  const values = Object.fromEntries(
    argv
      .filter((arg) => arg.startsWith('--') && arg.includes('='))
      .map((arg) => {
        const [key, ...rest] = arg.slice(2).split('=');
        return [key, rest.join('=')];
      }),
  );
  return {
    url: values.url || 'http://127.0.0.1:3000/api/v1/health',
    requests: Number(values.requests || 100),
    concurrency: Number(values.concurrency || 10),
    method: String(values.method || 'GET').toUpperCase(),
    headers: parseJsonArg(values.headers, {}),
    body: values.body ? parseJsonArg(values.body, values.body) : undefined,
    timeoutMs: Number(values.timeoutMs || 5000),
    maxP95Ms: Number(values.maxP95Ms || 1000),
    maxErrorRate: Number(values.maxErrorRate || 0.01),
  };
}

function parseJsonArg(value, fallback) {
  if (!value) return fallback;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

if (require.main === module) {
  runLoadTest(parseArgs(process.argv.slice(2)))
    .then((summary) => {
      console.log(JSON.stringify(summary, null, 2));
      process.exit(summary.passed ? 0 : 1);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = {
  summarizeResults,
  runLoadTest,
  parseArgs,
};

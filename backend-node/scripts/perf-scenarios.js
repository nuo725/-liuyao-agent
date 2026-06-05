#!/usr/bin/env node

require('dotenv').config();
const { runLoadTest } = require('./perf-smoke');

const DEFAULT_SCENARIOS = [
  {
    name: 'community_feed',
    method: 'GET',
    path: '/api/v1/community/feed?tab=recommended&page=1&pageSize=20',
  },
  {
    name: 'post_detail',
    method: 'GET',
    path: ({ postId }) => `/api/v1/community/post/${postId}`,
    required: ['PERF_POST_ID'],
  },
  {
    name: 'comment_create',
    method: 'POST',
    path: ({ postId }) => `/api/v1/community/post/${postId}/comments`,
    required: ['PERF_POST_ID', 'PERF_AUTH_TOKEN'],
    idempotent: true,
    body: ({ runId }) => ({ text: `perf comment ${runId}` }),
  },
  {
    name: 'ritual_perform',
    method: 'POST',
    path: '/api/v1/ritual/perform',
    required: ['PERF_AUTH_TOKEN'],
    idempotent: true,
    body: ({ runId }) => ({
      question: `性能压测问题 ${runId}`,
      tag: 'relationship',
      lines: [0, 1, 0, 1, 0, 1],
      movingLines: [1, 4],
    }),
  },
];

async function runScenarioSuite({
  baseUrl = process.env.PERF_BASE_URL || 'http://127.0.0.1:3000',
  env = process.env,
  requests = Number(env.PERF_REQUESTS || 100),
  concurrency = Number(env.PERF_CONCURRENCY || 10),
  timeoutMs = Number(env.PERF_TIMEOUT_MS || 5000),
  maxP95Ms = Number(env.PERF_MAX_P95_MS || 1000),
  maxErrorRate = Number(env.PERF_MAX_ERROR_RATE || 0.01),
  scenarios = DEFAULT_SCENARIOS,
  loadTest = runLoadTest,
} = {}) {
  const context = {
    baseUrl: stripTrailingSlash(baseUrl),
    postId: env.PERF_POST_ID,
    token: env.PERF_AUTH_TOKEN,
    runId: env.PERF_RUN_ID || new Date().toISOString().replace(/[:.]/g, '-'),
  };

  const results = [];
  for (const scenario of scenarios) {
    results.push(await runScenario(scenario, {
      context,
      env,
      requests,
      concurrency,
      timeoutMs,
      maxP95Ms,
      maxErrorRate,
      loadTest,
    }));
  }

  return {
    baseUrl: context.baseUrl,
    requests,
    concurrency,
    thresholds: { maxP95Ms, maxErrorRate },
    results,
    passed: results.every((result) => result.passed === true),
  };
}

async function runScenario(scenario, options) {
  const missing = (scenario.required || []).filter((key) => !options.env[key]);
  if (missing.length > 0) {
    return {
      name: scenario.name,
      skipped: true,
      passed: false,
      reason: `Missing required environment: ${missing.join(', ')}`,
    };
  }

  const path = typeof scenario.path === 'function' ? scenario.path(options.context) : scenario.path;
  const body = typeof scenario.body === 'function' ? scenario.body(options.context) : scenario.body;
  const headers = buildHeaders(scenario, options.context);
  const summary = await options.loadTest({
    url: `${options.context.baseUrl}${path}`,
    method: scenario.method,
    headers,
    body,
    requests: options.requests,
    concurrency: options.concurrency,
    timeoutMs: options.timeoutMs,
    maxP95Ms: options.maxP95Ms,
    maxErrorRate: options.maxErrorRate,
  });

  return {
    name: scenario.name,
    method: scenario.method,
    path,
    passed: summary.passed,
    summary,
  };
}

function buildHeaders(scenario, context) {
  const headers = {};
  if ((scenario.required || []).includes('PERF_AUTH_TOKEN')) {
    headers.Authorization = `Bearer ${context.token}`;
  }
  if (scenario.idempotent) {
    headers['Idempotency-Key'] = `perf-${scenario.name}-${context.runId}`;
  }
  return headers;
}

function stripTrailingSlash(value) {
  return String(value || '').replace(/\/+$/, '');
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
    baseUrl: values.baseUrl || process.env.PERF_BASE_URL || 'http://127.0.0.1:3000',
    requests: Number(values.requests || process.env.PERF_REQUESTS || 100),
    concurrency: Number(values.concurrency || process.env.PERF_CONCURRENCY || 10),
    timeoutMs: Number(values.timeoutMs || process.env.PERF_TIMEOUT_MS || 5000),
    maxP95Ms: Number(values.maxP95Ms || process.env.PERF_MAX_P95_MS || 1000),
    maxErrorRate: Number(values.maxErrorRate || process.env.PERF_MAX_ERROR_RATE || 0.01),
  };
}

if (require.main === module) {
  runScenarioSuite(parseArgs(process.argv.slice(2)))
    .then((report) => {
      console.log(JSON.stringify(report, null, 2));
      process.exit(report.passed ? 0 : 1);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = {
  DEFAULT_SCENARIOS,
  buildHeaders,
  runScenarioSuite,
};

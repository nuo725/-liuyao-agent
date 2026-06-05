#!/usr/bin/env node

const REMAINING_ITEMS = {
  'DB-001': {
    title: 'Prisma migration baseline and rollback',
    commands: [
      'npm run db:deploy',
      'npm run db:seed',
      'npm run db:backup',
      'npm run db:restore -- --file=<backup-file> --clean',
    ],
    evidence: [
      'Environment name',
      'Commit SHA',
      'db:deploy output',
      'db:seed output',
      'Backup file and manifest',
      'Restore output',
      'Post-restore validation query or endpoint result',
    ],
  },
  'FE-CONTRACT-001': {
    title: 'Flutter main page contract regression',
    commands: [
      '$env:RUN_CONTRACT_DB="1"',
      'npm run test:contract',
    ],
    evidence: [
      'Backend base URL',
      'Test account',
      'Contract test output',
      'Flutter screen checklist',
      'Failure screenshots or logs if any',
    ],
  },
  'OPS-VERIFY-001': {
    title: 'Backup and restore drill',
    commands: [
      'npm run db:backup',
      'npm run db:restore -- --file=<backup-file> --clean',
    ],
    evidence: [
      'Backup file and manifest',
      'Restore target database',
      'Restore output',
      'Post-restore verification result',
    ],
  },
  'OPS-VERIFY-002': {
    title: 'Performance report',
    commands: [
      '$env:PERF_BASE_URL="<staging-backend-url>"',
      '$env:PERF_AUTH_TOKEN="<staging-user-access-token>"',
      '$env:PERF_POST_ID="<published-post-id>"',
      'npm run ops:perf-scenarios -- --requests=500 --concurrency=25 --maxP95Ms=800 --maxErrorRate=0.01',
    ],
    evidence: [
      'Scenario output JSON',
      'Request count and concurrency',
      'P50/P95/max latency per scenario',
      'Error rate and status code distribution per scenario',
      'Follow-up issue for threshold breach if any',
    ],
  },
  'OPS-VERIFY-003': {
    title: 'Monitoring dashboard and alert integration',
    commands: [
      'curl <base-url>/api/v1/ready',
      'curl <base-url>/api/v1/metrics',
      '$env:MONITOR_BASE_URL="<staging-backend-url>"',
      '$env:ALERT_WEBHOOK_URL="<webhook-url>"',
      'npm run ops:alert-check',
    ],
    evidence: [
      'Dashboard screenshot or link',
      '/ready output',
      '/metrics output',
      'Alert webhook payload',
      'Alert receiver delivery record',
    ],
  },
  'ADAPTER-001': {
    title: 'External provider regression',
    commands: [
      '$env:ADAPTER_CHECK_STRICT="1"',
      'npm run ops:adapter-check',
    ],
    evidence: [
      'SMS provider request ID',
      'WeChat OAuth callback log',
      'QQ OAuth callback log',
      'Object storage upload/fetch/cleanup record',
      'Push delivery record and worker job ID',
      'Payment valid/invalid signature callback logs',
      'Liuyao Agent service-auth and failure-path record when adapter is enabled',
    ],
  },
};

function buildEvidenceReport({
  item = 'ALL',
  environment = '<environment>',
  commit = '<commit-sha>',
  date = new Date().toISOString().slice(0, 10),
} = {}) {
  const itemIds = normalizeItems(item);
  return [
    '# Backend Release Acceptance Evidence',
    '',
    `Date: ${date}`,
    `Environment: ${environment}`,
    `Commit SHA: ${commit}`,
    '',
    ...itemIds.flatMap((itemId) => buildItemSection(itemId, REMAINING_ITEMS[itemId])),
  ].join('\n');
}

function buildItemSection(itemId, config) {
  if (!config) {
    throw new Error(`Unknown acceptance item: ${itemId}`);
  }
  return [
    `## ${itemId}: ${config.title}`,
    '',
    '### Commands',
    '',
    '```text',
    ...config.commands,
    '```',
    '',
    '### Required Evidence',
    '',
    ...config.evidence.map((line) => `- [ ] ${line}`),
    '',
    '### Result',
    '',
    '- Status: <pass|fail|partial>',
    '- Evidence files/links: <links>',
    '- Follow-up issues: <links or none>',
    '',
  ];
}

function normalizeItems(item) {
  if (!item || item === 'ALL' || item === 'remaining') {
    return Object.keys(REMAINING_ITEMS);
  }
  const values = String(item)
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  for (const value of values) {
    if (!REMAINING_ITEMS[value]) {
      throw new Error(`Unknown acceptance item: ${value}`);
    }
  }
  return values;
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
    item: values.item || 'ALL',
    environment: values.environment || '<environment>',
    commit: values.commit || '<commit-sha>',
    date: values.date || new Date().toISOString().slice(0, 10),
  };
}

if (require.main === module) {
  try {
    console.log(buildEvidenceReport(parseArgs(process.argv.slice(2))));
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = {
  REMAINING_ITEMS,
  buildEvidenceReport,
  normalizeItems,
  parseArgs,
};

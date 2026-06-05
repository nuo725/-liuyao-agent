#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const REQUIRED_FILES = [
  '../BACKEND_TDL_AND_DELIVERY_PLAN.md',
  '../PRODUCT_PRD.md',
  'PROGRESS.md',
  'docs/release-acceptance-runbook.md',
  'docs/acceptance-traceability.md',
  'docs/db-migration-baseline.md',
  'docs/adapter-readiness.md',
  'docs/performance-verification.md',
  'prisma/schema.prisma',
  'prisma/migrations/202606050001_initial_schema/migration.sql',
  'prisma/migrations/202606050002_rate_limit_buckets/migration.sql',
  'scripts/acceptance-evidence.js',
  'scripts/acceptance-evidence-validate.js',
  'scripts/acceptance-package.js',
  'scripts/acceptance-status.js',
];

const REQUIRED_PACKAGE_SCRIPTS = [
  'db:deploy',
  'db:seed',
  'db:backup',
  'db:restore',
  'test:contract',
  'ops:adapter-check',
  'ops:perf-scenarios',
  'ops:alert-check',
  'ops:acceptance-evidence',
  'ops:acceptance-evidence:check',
  'ops:acceptance-package',
  'ops:acceptance-status',
];

const REQUIRED_REMAINING_ITEMS = [
  'DB-001',
  'OPS-VERIFY-001',
  'OPS-VERIFY-002',
  'OPS-VERIFY-003',
  'FE-CONTRACT-001',
  'ADAPTER-001',
];

function runAcceptancePreflight({ rootDir = process.cwd() } = {}) {
  const checks = [
    ...checkRequiredFiles(rootDir),
    ...checkPackageScripts(rootDir),
    ...checkProgressDocument(rootDir),
    ...checkTraceabilityDocument(rootDir),
  ];
  return {
    ok: checks.every((check) => check.status === 'pass'),
    checks,
  };
}

function checkRequiredFiles(rootDir) {
  return REQUIRED_FILES.map((file) => {
    const filePath = path.resolve(rootDir, file);
    return {
      name: `file:${file}`,
      status: fs.existsSync(filePath) ? 'pass' : 'fail',
      detail: fs.existsSync(filePath) ? 'exists' : `missing ${file}`,
    };
  });
}

function checkPackageScripts(rootDir) {
  const packageJson = readJson(path.join(rootDir, 'package.json'));
  const scripts = packageJson.scripts || {};
  return REQUIRED_PACKAGE_SCRIPTS.map((script) => ({
    name: `script:${script}`,
    status: scripts[script] ? 'pass' : 'fail',
    detail: scripts[script] || 'missing script',
  }));
}

function checkProgressDocument(rootDir) {
  const progress = readText(path.join(rootDir, 'PROGRESS.md'));
  const rows = extractAcceptanceRows(progress);
  const completed = rows.filter((row) => row.status.includes('✅')).length;
  const progressCounts = [...progress.matchAll(/\*\*上线验收进度：(\d+)\/(\d+)/g)].map((match) => ({
    completed: Number(match[1]),
    total: Number(match[2]),
  }));
  const remainingIds = rows.filter((row) => !row.status.includes('✅')).map((row) => row.id);

  return [
    {
      name: 'progress:acceptance-row-count',
      status: rows.length === 11 ? 'pass' : 'fail',
      detail: `${rows.length}/11 rows`,
    },
    {
      name: 'progress:completed-count',
      status: completed === 5 ? 'pass' : 'fail',
      detail: `${completed}/5 completed`,
    },
    {
      name: 'progress:published-counts',
      status: progressCounts.length >= 2 && progressCounts.every((count) => count.completed === 5 && count.total === 11)
        ? 'pass'
        : 'fail',
      detail: progressCounts.map((count) => `${count.completed}/${count.total}`).join(', '),
    },
    {
      name: 'progress:remaining-items',
      status: sameSet(remainingIds, REQUIRED_REMAINING_ITEMS) ? 'pass' : 'fail',
      detail: remainingIds.join(', '),
    },
  ];
}

function checkTraceabilityDocument(rootDir) {
  const traceability = readText(path.join(rootDir, 'docs', 'acceptance-traceability.md'));
  return REQUIRED_REMAINING_ITEMS.map((itemId) => ({
    name: `traceability:${itemId}`,
    status: traceability.includes(`| ${itemId} |`) ? 'pass' : 'fail',
    detail: traceability.includes(`| ${itemId} |`) ? 'mapped' : 'missing mapping',
  }));
}

function extractAcceptanceRows(progress) {
  const start = progress.indexOf('## 上线验收矩阵');
  const end = progress.indexOf('**上线验收进度', start);
  if (start === -1 || end === -1) {
    return [];
  }
  return progress
    .slice(start, end)
    .split(/\r?\n/)
    .map((line) => line.match(/^\| ([A-Z0-9-]+) \| ([^|]+) \| ([^|]+) \|/))
    .filter(Boolean)
    .map((match) => ({ id: match[1], name: match[2].trim(), status: match[3].trim() }))
    .filter((row) => row.id !== 'ID');
}

function formatPreflightReport(result, { format = 'text' } = {}) {
  if (format === 'json') {
    return JSON.stringify(result, null, 2);
  }
  return [
    '# Acceptance Preflight',
    '',
    `Ready for external acceptance: ${result.ok ? 'yes' : 'no'}`,
    '',
    '| Check | Status | Detail |',
    '|-------|--------|--------|',
    ...result.checks.map((check) => `| ${check.name} | ${check.status} | ${escapeTableCell(check.detail)} |`),
  ].join('\n');
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
    rootDir: values.root || process.cwd(),
    format: values.format || 'text',
  };
}

function readJson(filePath) {
  return JSON.parse(readText(filePath));
}

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function sameSet(left, right) {
  return left.length === right.length && left.every((value) => right.includes(value));
}

function escapeTableCell(value) {
  return String(value).replaceAll('|', '\\|');
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const result = runAcceptancePreflight(args);
    console.log(formatPreflightReport(result, args));
    if (!result.ok) {
      process.exitCode = 1;
    }
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = {
  REQUIRED_FILES,
  REQUIRED_PACKAGE_SCRIPTS,
  REQUIRED_REMAINING_ITEMS,
  extractAcceptanceRows,
  formatPreflightReport,
  parseArgs,
  runAcceptancePreflight,
};

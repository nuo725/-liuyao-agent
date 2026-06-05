#!/usr/bin/env node

const path = require('node:path');
const { runAcceptancePreflight } = require('./acceptance-preflight');
const { summarizeAcceptancePackage } = require('./acceptance-status');
const { verifyAcceptanceSeal } = require('./acceptance-seal');

function runAcceptanceGate({
  rootDir = process.cwd(),
  packageDir,
  manifestFile,
  evidenceFile,
  sealFile,
} = {}) {
  const checks = [];
  const preflight = runAcceptancePreflight({ rootDir });
  checks.push({
    name: 'preflight',
    status: preflight.ok ? 'pass' : 'fail',
    detail: summarizeFailedChecks(preflight.checks),
  });

  let statusSummary = null;
  if (packageDir || manifestFile) {
    statusSummary = summarizeAcceptancePackage({ packageDir, manifestFile, evidenceFile });
    checks.push({
      name: 'acceptance-status',
      status: statusSummary.ready ? 'pass' : 'fail',
      detail: `progress ${statusSummary.passed}/${statusSummary.total}`,
    });
  } else {
    checks.push({
      name: 'acceptance-status',
      status: 'fail',
      detail: 'missing --package or --manifest',
    });
  }

  if (sealFile) {
    const seal = verifyAcceptanceSeal({ packageDir, sealFile });
    checks.push({
      name: 'acceptance-seal',
      status: seal.ok ? 'pass' : 'fail',
      detail: summarizeFailedChecks(seal.checks),
    });
  } else {
    checks.push({
      name: 'acceptance-seal',
      status: 'fail',
      detail: 'missing --seal',
    });
  }

  return {
    ok: checks.every((check) => check.status === 'pass'),
    rootDir,
    packageDir,
    manifestFile,
    evidenceFile,
    sealFile,
    checks,
    statusSummary,
  };
}

function summarizeFailedChecks(checks) {
  const failed = checks.filter((check) => check.status !== 'pass');
  if (failed.length === 0) {
    return 'ok';
  }
  return failed.map((check) => `${check.name || check.path}: ${check.detail || check.status}`).join('; ');
}

function formatGateReport(result, { format = 'text' } = {}) {
  if (format === 'json') {
    return JSON.stringify(result, null, 2);
  }
  return [
    '# Acceptance Release Gate',
    '',
    `Release accepted: ${result.ok ? 'yes' : 'no'}`,
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
  const packageDir = values.package || values.dir;
  return {
    rootDir: values.root || process.cwd(),
    packageDir,
    manifestFile: values.manifest,
    evidenceFile: values.evidence,
    sealFile: values.seal || (packageDir ? path.join(packageDir, 'acceptance-seal.json') : undefined),
    format: values.format || 'text',
  };
}

function escapeTableCell(value) {
  return String(value).replaceAll('|', '\\|');
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const result = runAcceptanceGate(args);
    console.log(formatGateReport(result, args));
    if (!result.ok) {
      process.exitCode = 1;
    }
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = {
  formatGateReport,
  parseArgs,
  runAcceptanceGate,
  summarizeFailedChecks,
};

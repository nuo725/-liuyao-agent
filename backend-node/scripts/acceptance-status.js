#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const { extractItemSection, validateEvidenceMarkdown } = require('./acceptance-evidence-validate');

function summarizeAcceptancePackage({ packageDir, manifestFile, evidenceFile } = {}) {
  const resolvedManifestFile = manifestFile || path.join(packageDir || '', 'acceptance-manifest.json');
  const manifest = JSON.parse(fs.readFileSync(resolvedManifestFile, 'utf8'));
  const resolvedEvidenceFile = evidenceFile || path.join(path.dirname(resolvedManifestFile), manifest.evidenceFile);
  const markdown = fs.readFileSync(resolvedEvidenceFile, 'utf8');
  const items = manifest.items.map((item) => summarizeItem(markdown, item));
  const counts = items.reduce(
    (acc, item) => {
      acc[item.status] = (acc[item.status] || 0) + 1;
      return acc;
    },
    { pass: 0, partial: 0, fail: 0, pending: 0 },
  );

  return {
    date: manifest.date,
    environment: manifest.environment,
    commit: manifest.commit,
    evidenceFile: resolvedEvidenceFile,
    manifestFile: resolvedManifestFile,
    total: items.length,
    passed: counts.pass || 0,
    counts,
    ready: items.length > 0 && items.every((item) => item.status === 'pass'),
    items,
  };
}

function summarizeItem(markdown, item) {
  const validation = validateEvidenceMarkdown(markdown, { item: item.id });
  const itemIssues = validation.issues.filter((issue) => issue.itemId === item.id || issue.itemId === 'HEADER');
  const section = extractItemSection(markdown, item.id);
  const resultStatus = section ? parseResultStatus(section) : null;
  const status = deriveStatus({ validation, resultStatus });
  return {
    id: item.id,
    title: item.title,
    status,
    issueCount: itemIssues.length,
    issues: itemIssues.map((issue) => issue.message),
  };
}

function deriveStatus({ validation, resultStatus }) {
  if (!validation.valid) {
    return 'pending';
  }
  if (resultStatus === 'pass' || resultStatus === 'partial' || resultStatus === 'fail') {
    return resultStatus;
  }
  return 'pending';
}

function parseResultStatus(section) {
  const match = section.match(/^- Status:\s*(pass|partial|fail)\s*$/im);
  return match ? match[1].toLowerCase() : null;
}

function formatStatusSummary(summary, { format = 'text' } = {}) {
  if (format === 'json') {
    return JSON.stringify(summary, null, 2);
  }
  return [
    '# Acceptance Package Status',
    '',
    `Environment: ${summary.environment}`,
    `Commit SHA: ${summary.commit}`,
    `Ready: ${summary.ready ? 'yes' : 'no'}`,
    `Progress: ${summary.passed}/${summary.total}`,
    '',
    '| Item | Status | Issues |',
    '|------|--------|--------|',
    ...summary.items.map((item) => `| ${item.id} | ${item.status} | ${formatIssues(item.issues)} |`),
  ].join('\n');
}

function formatIssues(issues) {
  return issues.length > 0 ? issues.join('; ') : 'none';
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
    packageDir: values.package || values.dir,
    manifestFile: values.manifest,
    evidenceFile: values.evidence,
    format: values.format || 'text',
  };
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2));
    if (!args.packageDir && !args.manifestFile) {
      throw new Error('Missing required argument: --package=<dir> or --manifest=<acceptance-manifest.json>');
    }
    const summary = summarizeAcceptancePackage(args);
    console.log(formatStatusSummary(summary, args));
    if (!summary.ready) {
      process.exitCode = 1;
    }
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = {
  deriveStatus,
  formatStatusSummary,
  parseArgs,
  parseResultStatus,
  summarizeAcceptancePackage,
  summarizeItem,
};

#!/usr/bin/env node

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function redactArgs(values) {
  return values.map((value, index) => (values[index - 1] === '--dbname' ? redactDatabaseUrl(value) : value));
}

function redactDatabaseUrl(value) {
  try {
    const url = new URL(value);
    if (url.password) url.password = '***';
    if (url.username) url.username = url.username ? `${url.username}` : '';
    return url.toString();
  } catch {
    return '<redacted-database-url>';
  }
}

function buildManifest({ outputFile, databaseUrl }) {
  return {
    file: path.basename(outputFile),
    createdAt: new Date().toISOString(),
    databaseUrl: redactDatabaseUrl(databaseUrl),
    format: 'pg_dump custom',
  };
}

function parseBackupArgs(argv) {
  const args = new Set(argv);
  const outArg = argv.find((arg) => arg.startsWith('--out='));
  return {
    dryRun: args.has('--dry-run'),
    outputDir: outArg ? outArg.slice('--out='.length) : 'backups',
  };
}

function runBackup({
  databaseUrl = process.env.DATABASE_URL,
  pgDump = process.env.PG_DUMP_BIN || 'pg_dump',
  outputDir = 'backups',
  dryRun = false,
  cwd = process.cwd(),
} = {}) {
  if (!databaseUrl) {
    return { ok: false, error: 'DATABASE_URL is required' };
  }

  const resolvedDir = path.resolve(cwd, outputDir);
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outputFile = path.join(resolvedDir, `zhouyi-${timestamp}.dump`);
  const commandArgs = [
    '--dbname',
    databaseUrl,
    '--format',
    'custom',
    '--no-owner',
    '--no-privileges',
    '--file',
    outputFile,
  ];

  if (dryRun) {
    return {
      ok: true,
      dryRun: true,
      outputFile,
      command: `${pgDump} ${redactArgs(commandArgs).join(' ')}`,
    };
  }

  fs.mkdirSync(resolvedDir, { recursive: true });
  const result = spawnSync(pgDump, commandArgs, { stdio: 'inherit' });
  if (result.error) {
    return { ok: false, error: `Failed to run ${pgDump}: ${result.error.message}` };
  }
  if (result.status !== 0) {
    return { ok: false, error: `${pgDump} exited with code ${result.status || 1}` };
  }

  const manifest = buildManifest({ outputFile, databaseUrl });
  fs.writeFileSync(`${outputFile}.manifest.json`, `${JSON.stringify(manifest, null, 2)}\n`);
  return { ok: true, outputFile, manifest };
}

if (require.main === module) {
  require('dotenv').config();
  const parsed = parseBackupArgs(process.argv.slice(2));
  const result = runBackup({ outputDir: parsed.outputDir, dryRun: parsed.dryRun });
  if (!result.ok) {
    console.error(result.error);
    process.exit(1);
  }
  if (result.dryRun) {
    console.log(`Would create backup: ${result.outputFile}`);
    console.log(result.command);
  } else {
    console.log(`Backup created: ${result.outputFile}`);
  }
}

module.exports = {
  redactDatabaseUrl,
  redactArgs,
  buildManifest,
  parseBackupArgs,
  runBackup,
};

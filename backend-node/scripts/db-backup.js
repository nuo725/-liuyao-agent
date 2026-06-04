#!/usr/bin/env node

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const args = new Set(process.argv.slice(2));
const outArg = process.argv.find((arg) => arg.startsWith('--out='));
const dryRun = args.has('--dry-run');
const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  console.error('DATABASE_URL is required');
  process.exit(1);
}

const outputDir = path.resolve(process.cwd(), outArg ? outArg.slice('--out='.length) : 'backups');
const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
const outputFile = path.join(outputDir, `zhouyi-${timestamp}.dump`);
const pgDump = process.env.PG_DUMP_BIN || 'pg_dump';
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
  console.log(`Would create backup: ${outputFile}`);
  console.log(`${pgDump} ${redactArgs(commandArgs).join(' ')}`);
  process.exit(0);
}

fs.mkdirSync(outputDir, { recursive: true });
const result = spawnSync(pgDump, commandArgs, { stdio: 'inherit' });
if (result.error) {
  console.error(`Failed to run ${pgDump}: ${result.error.message}`);
  process.exit(1);
}
if (result.status !== 0) {
  process.exit(result.status || 1);
}

const manifest = {
  file: path.basename(outputFile),
  createdAt: new Date().toISOString(),
  databaseUrl: redactDatabaseUrl(databaseUrl),
  format: 'pg_dump custom',
};
fs.writeFileSync(`${outputFile}.manifest.json`, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Backup created: ${outputFile}`);

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

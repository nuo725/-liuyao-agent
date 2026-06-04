#!/usr/bin/env node

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const args = process.argv.slice(2);
const fileArg = args.find((arg) => arg.startsWith('--file='));
const dryRun = args.includes('--dry-run');
const clean = args.includes('--clean');
const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  console.error('DATABASE_URL is required');
  process.exit(1);
}
if (!fileArg) {
  console.error('Usage: node scripts/db-restore.js --file=backups/zhouyi.dump [--clean] [--dry-run]');
  process.exit(1);
}

const inputFile = path.resolve(process.cwd(), fileArg.slice('--file='.length));
if (!dryRun && !fs.existsSync(inputFile)) {
  console.error(`Backup file not found: ${inputFile}`);
  process.exit(1);
}

const isSql = inputFile.toLowerCase().endsWith('.sql');
const command = isSql ? process.env.PSQL_BIN || 'psql' : process.env.PG_RESTORE_BIN || 'pg_restore';
const commandArgs = isSql
  ? ['--dbname', databaseUrl, '--file', inputFile]
  : [
      '--dbname',
      databaseUrl,
      '--no-owner',
      '--no-privileges',
      ...(clean ? ['--clean', '--if-exists'] : []),
      inputFile,
    ];

if (dryRun) {
  console.log(`Would restore backup: ${inputFile}`);
  console.log(`${command} ${redactArgs(commandArgs).join(' ')}`);
  process.exit(0);
}

const result = spawnSync(command, commandArgs, { stdio: 'inherit' });
if (result.error) {
  console.error(`Failed to run ${command}: ${result.error.message}`);
  process.exit(1);
}
process.exit(result.status || 0);

function redactArgs(values) {
  return values.map((value, index) => (values[index - 1] === '--dbname' ? redactDatabaseUrl(value) : value));
}

function redactDatabaseUrl(value) {
  try {
    const url = new URL(value);
    if (url.password) url.password = '***';
    return url.toString();
  } catch {
    return '<redacted-database-url>';
  }
}

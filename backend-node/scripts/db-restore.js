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
    return url.toString();
  } catch {
    return '<redacted-database-url>';
  }
}

function parseRestoreArgs(argv) {
  const fileArg = argv.find((arg) => arg.startsWith('--file='));
  return {
    file: fileArg ? fileArg.slice('--file='.length) : null,
    dryRun: argv.includes('--dry-run'),
    clean: argv.includes('--clean'),
  };
}

function buildRestoreCommand({ inputFile, databaseUrl, clean }) {
  const isSql = inputFile.toLowerCase().endsWith('.sql');
  const command = isSql ? (process.env.PSQL_BIN || 'psql') : (process.env.PG_RESTORE_BIN || 'pg_restore');
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
  return { command, commandArgs, isSql };
}

function runRestore({
  file,
  databaseUrl = process.env.DATABASE_URL,
  dryRun = false,
  clean = false,
  cwd = process.cwd(),
} = {}) {
  if (!databaseUrl) {
    return { ok: false, error: 'DATABASE_URL is required' };
  }
  if (!file) {
    return { ok: false, error: 'Usage: node scripts/db-restore.js --file=backups/zhouyi.dump [--clean] [--dry-run]' };
  }

  const inputFile = path.resolve(cwd, file);
  if (!dryRun && !fs.existsSync(inputFile)) {
    return { ok: false, error: `Backup file not found: ${inputFile}` };
  }

  const { command, commandArgs } = buildRestoreCommand({ inputFile, databaseUrl, clean });

  if (dryRun) {
    return {
      ok: true,
      dryRun: true,
      inputFile,
      command: `${command} ${redactArgs(commandArgs).join(' ')}`,
    };
  }

  const result = spawnSync(command, commandArgs, { stdio: 'inherit' });
  if (result.error) {
    return { ok: false, error: `Failed to run ${command}: ${result.error.message}` };
  }
  if (result.status !== 0) {
    return { ok: false, error: `${command} exited with code ${result.status || 1}` };
  }
  return { ok: true, inputFile };
}

if (require.main === module) {
  require('dotenv').config();
  const parsed = parseRestoreArgs(process.argv.slice(2));
  const result = runRestore({ file: parsed.file, dryRun: parsed.dryRun, clean: parsed.clean });
  if (!result.ok) {
    console.error(result.error);
    process.exit(1);
  }
  if (result.dryRun) {
    console.log(`Would restore backup: ${result.inputFile}`);
    console.log(result.command);
  }
}

module.exports = {
  redactDatabaseUrl,
  redactArgs,
  parseRestoreArgs,
  buildRestoreCommand,
  runRestore,
};

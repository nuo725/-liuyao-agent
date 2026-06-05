#!/usr/bin/env node

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_SEAL_FILE = 'acceptance-seal.json';

function sealAcceptancePackage({
  packageDir,
  outFile,
  include = ['acceptance-evidence.md', 'acceptance-manifest.json'],
  generatedAt = new Date().toISOString(),
} = {}) {
  if (!packageDir) {
    throw new Error('Missing required option: packageDir');
  }

  const resolvedPackageDir = path.resolve(packageDir);
  const files = include.map((file) => buildFileSeal(resolvedPackageDir, file));
  const seal = {
    generatedAt,
    packageDir: resolvedPackageDir,
    algorithm: 'sha256',
    files,
  };
  const resolvedOutFile = path.resolve(outFile || path.join(resolvedPackageDir, DEFAULT_SEAL_FILE));
  fs.writeFileSync(resolvedOutFile, `${JSON.stringify(seal, null, 2)}\n`, 'utf8');

  return {
    sealFile: resolvedOutFile,
    seal,
  };
}

function buildFileSeal(packageDir, relativePath) {
  const filePath = path.resolve(packageDir, relativePath);
  assertInsidePackage(packageDir, filePath);
  const buffer = fs.readFileSync(filePath);
  return {
    path: relativePath.replaceAll('\\', '/'),
    bytes: buffer.length,
    sha256: crypto.createHash('sha256').update(buffer).digest('hex'),
  };
}

function assertInsidePackage(packageDir, filePath) {
  const relative = path.relative(packageDir, filePath);
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`Refusing to seal file outside package: ${filePath}`);
  }
}

function verifyAcceptanceSeal({ packageDir, sealFile } = {}) {
  if (!sealFile) {
    throw new Error('Missing required option: sealFile');
  }
  const seal = JSON.parse(fs.readFileSync(sealFile, 'utf8'));
  const resolvedPackageDir = path.resolve(packageDir || seal.packageDir);
  const checks = seal.files.map((file) => {
    const current = buildFileSeal(resolvedPackageDir, file.path);
    const ok = current.sha256 === file.sha256 && current.bytes === file.bytes;
    return {
      path: file.path,
      status: ok ? 'pass' : 'fail',
      expectedSha256: file.sha256,
      actualSha256: current.sha256,
      expectedBytes: file.bytes,
      actualBytes: current.bytes,
    };
  });
  return {
    ok: checks.every((check) => check.status === 'pass'),
    algorithm: seal.algorithm,
    checks,
  };
}

function formatSealReport(result, { format = 'text' } = {}) {
  if (format === 'json') {
    return JSON.stringify(result, null, 2);
  }
  const checks = result.checks || result.seal.files.map((file) => ({
    path: file.path,
    status: 'sealed',
    actualSha256: file.sha256,
    actualBytes: file.bytes,
  }));
  return [
    '# Acceptance Seal',
    '',
    `OK: ${result.ok === false ? 'no' : 'yes'}`,
    `Algorithm: ${result.algorithm || result.seal.algorithm}`,
    '',
    '| File | Status | Bytes | SHA-256 |',
    '|------|--------|-------|---------|',
    ...checks.map((check) => `| ${check.path} | ${check.status} | ${check.actualBytes} | ${check.actualSha256} |`),
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
  const flags = new Set(argv.filter((arg) => arg.startsWith('--') && !arg.includes('=')).map((arg) => arg.slice(2)));
  return {
    packageDir: values.package || values.dir,
    outFile: values.out,
    sealFile: values.seal,
    include: values.include ? values.include.split(',').map((file) => file.trim()).filter(Boolean) : undefined,
    verify: flags.has('verify') || values.verify === '1' || values.verify === 'true',
    format: values.format || 'text',
  };
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const result = args.verify
      ? verifyAcceptanceSeal(args)
      : sealAcceptancePackage(args);
    console.log(formatSealReport(result, args));
    if (result.ok === false) {
      process.exitCode = 1;
    }
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = {
  buildFileSeal,
  formatSealReport,
  parseArgs,
  sealAcceptancePackage,
  verifyAcceptanceSeal,
};

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createAcceptancePackage } = require('../../scripts/acceptance-package');
const {
  buildFileSeal,
  formatSealReport,
  parseArgs,
  sealAcceptancePackage,
  verifyAcceptanceSeal,
} = require('../../scripts/acceptance-seal');

describe('Acceptance seal', () => {
  it('creates a SHA-256 seal for an acceptance package', () => {
    const packageDir = makePackage();

    const result = sealAcceptancePackage({ packageDir, generatedAt: '2026-06-05T00:00:00.000Z' });

    assert.equal(fs.existsSync(result.sealFile), true);
    assert.equal(result.seal.algorithm, 'sha256');
    assert.deepEqual(
      result.seal.files.map((file) => file.path),
      ['acceptance-evidence.md', 'acceptance-manifest.json'],
    );
    assert.match(result.seal.files[0].sha256, /^[a-f0-9]{64}$/);
  });

  it('verifies an unchanged sealed package', () => {
    const packageDir = makePackage();
    const { sealFile } = sealAcceptancePackage({ packageDir });

    const result = verifyAcceptanceSeal({ sealFile });

    assert.equal(result.ok, true);
    assert.ok(result.checks.every((check) => check.status === 'pass'));
  });

  it('fails verification after evidence changes', () => {
    const packageDir = makePackage();
    const { sealFile } = sealAcceptancePackage({ packageDir });
    fs.appendFileSync(path.join(packageDir, 'acceptance-evidence.md'), '\nchanged after seal\n', 'utf8');

    const result = verifyAcceptanceSeal({ sealFile });

    assert.equal(result.ok, false);
    assert.ok(result.checks.some((check) => check.status === 'fail'));
  });

  it('refuses to seal files outside the package directory', () => {
    const packageDir = makePackage();

    assert.throws(() => buildFileSeal(packageDir, '../outside.md'), /outside package/);
  });

  it('formats text and json reports', () => {
    const packageDir = makePackage();
    const result = sealAcceptancePackage({ packageDir });

    assert.match(formatSealReport(result), /Acceptance Seal/);
    assert.match(formatSealReport(result), /acceptance-evidence\.md/);
    assert.match(formatSealReport(result, { format: 'json' }), /"algorithm": "sha256"/);
  });

  it('parses CLI arguments', () => {
    assert.deepEqual(
      parseArgs([
        '--package=release-evidence/staging',
        '--out=release-evidence/staging/seal.json',
        '--include=acceptance-evidence.md,acceptance-manifest.json',
        '--format=json',
      ]),
      {
        packageDir: 'release-evidence/staging',
        outFile: 'release-evidence/staging/seal.json',
        sealFile: undefined,
        include: ['acceptance-evidence.md', 'acceptance-manifest.json'],
        verify: false,
        format: 'json',
      },
    );
  });
});

function makePackage() {
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'acceptance-seal-'));
  createAcceptancePackage({
    outDir,
    item: 'DB-001',
    environment: 'staging',
    commit: 'abc1234',
    date: '2026-06-05',
  });
  return outDir;
}

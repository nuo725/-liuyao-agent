const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {
  buildManifest,
  createAcceptancePackage,
  formatPackageSummary,
  parseArgs,
} = require('../../scripts/acceptance-package');

describe('Acceptance package', () => {
  it('creates markdown evidence and manifest files', () => {
    const outDir = makeTempDir();

    const result = createAcceptancePackage({
      outDir,
      item: 'DB-001',
      environment: 'staging',
      commit: 'abc1234',
      date: '2026-06-05',
    });

    assert.deepEqual(result.itemIds, ['DB-001']);
    assert.equal(fs.existsSync(result.evidenceFile), true);
    assert.equal(fs.existsSync(result.manifestFile), true);

    const markdown = fs.readFileSync(result.evidenceFile, 'utf8');
    assert.match(markdown, /DB-001: Prisma migration baseline and rollback/);
    assert.match(markdown, /Environment: staging/);
    assert.doesNotMatch(markdown, /ADAPTER-001/);

    const manifest = JSON.parse(fs.readFileSync(result.manifestFile, 'utf8'));
    assert.equal(manifest.environment, 'staging');
    assert.equal(manifest.commit, 'abc1234');
    assert.equal(manifest.items[0].status, 'pending-external-evidence');
  });

  it('builds a manifest for multiple selected items', () => {
    const manifest = buildManifest({
      itemIds: ['OPS-VERIFY-002', 'ADAPTER-001'],
      environment: 'preprod',
      commit: 'ff45af8',
      date: '2026-06-05',
      evidenceFile: 'acceptance-evidence.md',
    });

    assert.deepEqual(
      manifest.items.map((item) => item.id),
      ['OPS-VERIFY-002', 'ADAPTER-001'],
    );
    assert.ok(manifest.items.every((item) => item.requiredEvidenceCount > 0));
    assert.ok(manifest.items.every((item) => item.commandCount > 0));
  });

  it('parses CLI arguments', () => {
    assert.deepEqual(
      parseArgs([
        '--out=release-evidence/preprod',
        '--item=DB-001,OPS-VERIFY-001',
        '--environment=preprod',
        '--commit=bc0d425',
        '--date=2026-06-05',
      ]),
      {
        outDir: 'release-evidence/preprod',
        item: 'DB-001,OPS-VERIFY-001',
        environment: 'preprod',
        commit: 'bc0d425',
        date: '2026-06-05',
      },
    );
  });

  it('formats a package summary for CI logs', () => {
    const summary = formatPackageSummary({
      outDir: 'release-evidence/preprod',
      evidenceFile: 'release-evidence/preprod/acceptance-evidence.md',
      manifestFile: 'release-evidence/preprod/acceptance-manifest.json',
      itemIds: ['DB-001'],
    });

    assert.match(summary, /Acceptance package created/);
    assert.match(summary, /acceptance-evidence\.md/);
    assert.match(summary, /DB-001/);
  });
});

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'acceptance-package-'));
}

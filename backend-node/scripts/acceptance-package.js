#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const { REMAINING_ITEMS, buildEvidenceReport, normalizeItems } = require('./acceptance-evidence');

function createAcceptancePackage({
  outDir = path.join('release-evidence', new Date().toISOString().slice(0, 10)),
  item = 'ALL',
  environment = '<environment>',
  commit = '<commit-sha>',
  date = new Date().toISOString().slice(0, 10),
} = {}) {
  const itemIds = normalizeItems(item);
  fs.mkdirSync(outDir, { recursive: true });

  const evidenceFile = path.join(outDir, 'acceptance-evidence.md');
  const manifestFile = path.join(outDir, 'acceptance-manifest.json');
  const markdown = buildEvidenceReport({ item: itemIds.join(','), environment, commit, date });
  const manifest = buildManifest({ itemIds, environment, commit, date, evidenceFile });

  fs.writeFileSync(evidenceFile, `${markdown}\n`, 'utf8');
  fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

  return {
    outDir,
    evidenceFile,
    manifestFile,
    itemIds,
  };
}

function buildManifest({ itemIds, environment, commit, date, evidenceFile }) {
  return {
    generatedAt: new Date().toISOString(),
    date,
    environment,
    commit,
    evidenceFile: path.basename(evidenceFile),
    items: itemIds.map((itemId) => ({
      id: itemId,
      title: REMAINING_ITEMS[itemId].title,
      requiredEvidenceCount: REMAINING_ITEMS[itemId].evidence.length,
      commandCount: REMAINING_ITEMS[itemId].commands.length,
      status: 'pending-external-evidence',
    })),
  };
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
    outDir: values.out || values['out-dir'],
    item: values.item || 'ALL',
    environment: values.environment || '<environment>',
    commit: values.commit || '<commit-sha>',
    date: values.date || new Date().toISOString().slice(0, 10),
  };
}

function formatPackageSummary(result) {
  return [
    `Acceptance package created: ${result.outDir}`,
    `Evidence: ${result.evidenceFile}`,
    `Manifest: ${result.manifestFile}`,
    `Items: ${result.itemIds.join(', ')}`,
  ].join('\n');
}

if (require.main === module) {
  try {
    const result = createAcceptancePackage(parseArgs(process.argv.slice(2)));
    console.log(formatPackageSummary(result));
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = {
  buildManifest,
  createAcceptancePackage,
  formatPackageSummary,
  parseArgs,
};

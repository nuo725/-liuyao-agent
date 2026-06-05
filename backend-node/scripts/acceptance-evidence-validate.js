#!/usr/bin/env node

const fs = require('node:fs');
const { REMAINING_ITEMS, normalizeItems } = require('./acceptance-evidence');

const HEADER_FIELDS = [
  { label: 'Date', pattern: /^Date:\s*(.+)$/m },
  { label: 'Environment', pattern: /^Environment:\s*(.+)$/m },
  { label: 'Commit SHA', pattern: /^Commit SHA:\s*(.+)$/m },
];

function validateEvidenceMarkdown(markdown, { item = 'ALL', requirePass = false } = {}) {
  const issues = [];
  const itemIds = normalizeItems(item);

  for (const field of HEADER_FIELDS) {
    const match = markdown.match(field.pattern);
    if (!match || hasPlaceholder(match[1])) {
      issues.push({ itemId: 'HEADER', message: `${field.label} is missing or still uses a placeholder.` });
    }
  }

  for (const itemId of itemIds) {
    const section = extractItemSection(markdown, itemId);
    if (!section) {
      issues.push({ itemId, message: 'Item section is missing.' });
      continue;
    }

    validateCommands(section, itemId, issues);
    validateRequiredEvidence(section, itemId, issues);
    validateResultFields(section, itemId, issues, { requirePass });
  }

  return {
    valid: issues.length === 0,
    itemIds,
    issueCount: issues.length,
    issues,
  };
}

function validateCommands(section, itemId, issues) {
  for (const command of REMAINING_ITEMS[itemId].commands) {
    if (!commandPattern(command).test(section)) {
      issues.push({ itemId, message: `Command evidence is missing: ${command}` });
    }
  }
}

function validateRequiredEvidence(section, itemId, issues) {
  for (const evidenceLine of REMAINING_ITEMS[itemId].evidence) {
    const unchecked = new RegExp(`^- \\[ \\] ${escapeRegExp(evidenceLine)}\\s*$`, 'm');
    const checked = new RegExp(`^- \\[[xX]\\] ${escapeRegExp(evidenceLine)}\\s*$`, 'm');
    if (unchecked.test(section)) {
      issues.push({ itemId, message: `Required evidence is still unchecked: ${evidenceLine}` });
    } else if (!checked.test(section)) {
      issues.push({ itemId, message: `Required evidence checklist line is missing: ${evidenceLine}` });
    }
  }
}

function validateResultFields(section, itemId, issues, { requirePass }) {
  const status = fieldValue(section, 'Status');
  if (!status || !/^(pass|fail|partial)$/i.test(status)) {
    issues.push({ itemId, message: 'Result status must be pass, fail, or partial.' });
  } else if (requirePass && status.toLowerCase() !== 'pass') {
    issues.push({ itemId, message: 'Result status must be pass when --require-pass=1 is used.' });
  }

  const evidenceLinks = fieldValue(section, 'Evidence files/links');
  if (!evidenceLinks || hasPlaceholder(evidenceLinks)) {
    issues.push({ itemId, message: 'Evidence files/links must be filled.' });
  }

  const followUps = fieldValue(section, 'Follow-up issues');
  if (!followUps || hasPlaceholder(followUps)) {
    issues.push({ itemId, message: 'Follow-up issues must be filled with links or none.' });
  }
}

function extractItemSection(markdown, itemId) {
  const lines = markdown.split(/\r?\n/);
  const start = lines.findIndex((line) => line.startsWith(`## ${itemId}:`));
  if (start === -1) {
    return null;
  }
  const next = lines.findIndex((line, index) => index > start && /^## [A-Z0-9-]+:/.test(line));
  return lines.slice(start, next === -1 ? undefined : next).join('\n');
}

function fieldValue(section, label) {
  const match = section.match(new RegExp(`^- ${escapeRegExp(label)}:\\s*(.+)$`, 'm'));
  return match ? match[1].trim() : null;
}

function commandPattern(command) {
  return new RegExp(escapeRegExp(command).replace(/<[^>]+>/g, '.+'));
}

function hasPlaceholder(value) {
  return /<[^>\n]+>|\b(TODO|TBD)\b/i.test(String(value));
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
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
    file: values.file,
    item: values.item || 'ALL',
    requirePass: values['require-pass'] === '1' || values['require-pass'] === 'true',
  };
}

function formatValidationReport(result) {
  if (result.valid) {
    return `Acceptance evidence check passed for ${result.itemIds.join(', ')}.`;
  }
  return [
    `Acceptance evidence check failed with ${result.issueCount} issue(s).`,
    ...result.issues.map((issue) => `- ${issue.itemId}: ${issue.message}`),
  ].join('\n');
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2));
    if (!args.file) {
      throw new Error('Missing required argument: --file=<evidence.md>');
    }
    const markdown = fs.readFileSync(args.file, 'utf8');
    const result = validateEvidenceMarkdown(markdown, args);
    console.log(formatValidationReport(result));
    if (!result.valid) {
      process.exit(1);
    }
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = {
  extractItemSection,
  formatValidationReport,
  parseArgs,
  validateEvidenceMarkdown,
};

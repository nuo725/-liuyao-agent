const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..', '..');

describe('Acceptance end-to-end flow', () => {
  describe('Script existence', () => {
    it('all acceptance scripts exist', () => {
      const scripts = [
        'acceptance-evidence.js',
        'acceptance-evidence-validate.js',
        'acceptance-gate.js',
        'acceptance-package.js',
        'acceptance-preflight.js',
        'acceptance-seal.js',
        'acceptance-status.js',
      ];
      for (const script of scripts) {
        const scriptPath = path.join(repoRoot, 'scripts', script);
        assert.ok(fs.existsSync(scriptPath), `${script} should exist`);
      }
    });

    it('all acceptance tests exist', () => {
      const tests = [
        'acceptance-evidence.test.js',
        'acceptance-evidence-validate.test.js',
        'acceptance-gate.test.js',
        'acceptance-package.test.js',
        'acceptance-preflight.test.js',
        'acceptance-seal.test.js',
        'acceptance-status.test.js',
        'acceptance-progress.test.js',
        'acceptance-traceability.test.js',
      ];
      for (const test of tests) {
        const testPath = path.join(repoRoot, 'test', 'unit', test);
        assert.ok(fs.existsSync(testPath), `${test} should exist`);
      }
    });
  });

  describe('Package.json scripts', () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(repoRoot, 'package.json'), 'utf8'));

    it('defines acceptance-related npm scripts', () => {
      const scripts = pkg.scripts || {};
      assert.ok(scripts['ops:acceptance-evidence'], 'should have acceptance-evidence script');
      assert.ok(scripts['ops:acceptance-evidence:check'], 'should have acceptance-evidence:check script');
      assert.ok(scripts['ops:acceptance-preflight'], 'should have acceptance-preflight script');
      assert.ok(scripts['ops:acceptance-package'], 'should have acceptance-package script');
      assert.ok(scripts['ops:acceptance-status'], 'should have acceptance-status script');
      assert.ok(scripts['ops:acceptance-seal'], 'should have acceptance-seal script');
      assert.ok(scripts['ops:acceptance-gate'], 'should have acceptance-gate script');
    });

    it('defines ops scripts for verification items', () => {
      const scripts = pkg.scripts || {};
      assert.ok(scripts['ops:security-check'], 'should have security-check script');
      assert.ok(scripts['ops:adapter-check'], 'should have adapter-check script');
      assert.ok(scripts['ops:perf-smoke'], 'should have perf-smoke script');
      assert.ok(scripts['ops:perf-scenarios'], 'should have perf-scenarios script');
      assert.ok(scripts['ops:alert-check'], 'should have alert-check script');
      assert.ok(scripts['ops:data-export'], 'should have data-export script');
      assert.ok(scripts['ops:data-delete'], 'should have data-delete script');
    });

    it('defines database scripts', () => {
      const scripts = pkg.scripts || {};
      assert.ok(scripts['db:migrate'], 'should have db:migrate script');
      assert.ok(scripts['db:deploy'], 'should have db:deploy script');
      assert.ok(scripts['db:generate'], 'should have db:generate script');
      assert.ok(scripts['db:seed'], 'should have db:seed script');
      assert.ok(scripts['db:backup'], 'should have db:backup script');
      assert.ok(scripts['db:restore'], 'should have db:restore script');
    });

    it('defines test scripts', () => {
      const scripts = pkg.scripts || {};
      assert.ok(scripts['test'], 'should have test script');
      assert.ok(scripts['test:unit'], 'should have test:unit script');
      assert.ok(scripts['test:integration'], 'should have test:integration script');
      assert.ok(scripts['test:contract'], 'should have test:contract script');
      assert.ok(scripts['lint'], 'should have lint script');
    });

    it('defines worker script', () => {
      const scripts = pkg.scripts || {};
      assert.ok(scripts['worker:outbox'], 'should have worker:outbox script');
    });
  });

  describe('Documentation completeness', () => {
    it('release acceptance runbook exists', () => {
      const runbookPath = path.join(repoRoot, 'docs', 'release-acceptance-runbook.md');
      assert.ok(fs.existsSync(runbookPath), 'release-acceptance-runbook.md should exist');
    });

    it('acceptance traceability doc exists', () => {
      const tracePath = path.join(repoRoot, 'docs', 'acceptance-traceability.md');
      assert.ok(fs.existsSync(tracePath), 'acceptance-traceability.md should exist');
    });

    it('ops runbook exists', () => {
      const opsPath = path.join(repoRoot, 'docs', 'ops-runbook.md');
      assert.ok(fs.existsSync(opsPath), 'ops-runbook.md should exist');
    });

    it('performance verification doc exists', () => {
      const perfPath = path.join(repoRoot, 'docs', 'performance-verification.md');
      assert.ok(fs.existsSync(perfPath), 'performance-verification.md should exist');
    });

    it('adapter readiness doc exists', () => {
      const adapterPath = path.join(repoRoot, 'docs', 'adapter-readiness.md');
      assert.ok(fs.existsSync(adapterPath), 'adapter-readiness.md should exist');
    });

    it('rate limit strategy doc exists', () => {
      const rlPath = path.join(repoRoot, 'docs', 'rate-limit-strategy.md');
      assert.ok(fs.existsSync(rlPath), 'rate-limit-strategy.md should exist');
    });

    it('agent integration boundary doc exists', () => {
      const agentPath = path.join(repoRoot, 'docs', 'agent-integration-boundary.md');
      assert.ok(fs.existsSync(agentPath), 'agent-integration-boundary.md should exist');
    });
  });

  describe('OpenAPI spec', () => {
    it('openapi.yaml exists', () => {
      const specPath = path.join(repoRoot, 'openapi', 'openapi.yaml');
      assert.ok(fs.existsSync(specPath), 'openapi.yaml should exist');
    });

    it('openapi.yaml is not empty', () => {
      const specPath = path.join(repoRoot, 'openapi', 'openapi.yaml');
      const content = fs.readFileSync(specPath, 'utf8');
      assert.ok(content.length > 100, 'spec should have substantial content');
    });
  });

  describe('Prisma schema and migrations', () => {
    it('schema.prisma exists', () => {
      const schemaPath = path.join(repoRoot, 'prisma', 'schema.prisma');
      assert.ok(fs.existsSync(schemaPath), 'schema.prisma should exist');
    });

    it('initial migration exists', () => {
      const migrationPath = path.join(repoRoot, 'prisma', 'migrations', '202606050001_initial_schema', 'migration.sql');
      assert.ok(fs.existsSync(migrationPath), 'initial migration should exist');
    });

    it('rate limit migration exists', () => {
      const migrationPath = path.join(repoRoot, 'prisma', 'migrations', '202606050002_rate_limit_buckets', 'migration.sql');
      assert.ok(fs.existsSync(migrationPath), 'rate limit migration should exist');
    });

    it('seed.js exists', () => {
      const seedPath = path.join(repoRoot, 'prisma', 'seed.js');
      assert.ok(fs.existsSync(seedPath), 'seed.js should exist');
    });

    it('migration lock exists', () => {
      const lockPath = path.join(repoRoot, 'prisma', 'migrations', 'migration_lock.toml');
      assert.ok(fs.existsSync(lockPath), 'migration_lock.toml should exist');
    });
  });

  describe('CI configuration', () => {
    it('GitHub Actions workflow exists', () => {
      const ciPath = path.join(repoRoot, '..', '.github', 'workflows', 'backend-node-ci.yml');
      // CI may be at repo root level
      const altPath = path.join(repoRoot, '.github', 'workflows', 'backend-node-ci.yml');
      assert.ok(
        fs.existsSync(ciPath) || fs.existsSync(altPath),
        'CI workflow should exist'
      );
    });

    it('ESLint config exists', () => {
      const eslintPath = path.join(repoRoot, 'eslint.config.js');
      assert.ok(fs.existsSync(eslintPath), 'eslint.config.js should exist');
    });
  });

  describe('Docker configuration', () => {
    it('docker-compose.yml exists', () => {
      const dockerPath = path.join(repoRoot, 'docker-compose.yml');
      assert.ok(fs.existsSync(dockerPath), 'docker-compose.yml should exist');
    });

    it('docker-compose defines PostgreSQL service', () => {
      const dockerPath = path.join(repoRoot, 'docker-compose.yml');
      const content = fs.readFileSync(dockerPath, 'utf8');
      assert.ok(content.includes('postgres'), 'should define postgres service');
      assert.ok(content.includes('5432'), 'should expose port 5432');
    });
  });
});

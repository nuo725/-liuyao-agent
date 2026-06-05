const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..', '..');
const pkg = JSON.parse(fs.readFileSync(path.join(repoRoot, 'package.json'), 'utf8'));

function extractScriptTarget(script) {
  // Extract the main file path from a script command
  const parts = script.split(/\s+/);
  for (const part of parts) {
    if (part.endsWith('.js') && !part.startsWith('-')) {
      return part;
    }
  }
  return null;
}

describe('npm scripts verification', () => {
  describe('Script definitions', () => {
    it('has all required scripts', () => {
      const required = [
        'start', 'dev', 'test', 'test:unit', 'test:integration', 'test:contract',
        'lint', 'db:migrate', 'db:deploy', 'db:generate', 'db:seed', 'db:reset',
        'db:studio', 'db:backup', 'db:restore',
        'ops:security-check', 'ops:adapter-check', 'ops:perf-smoke', 'ops:perf-scenarios',
        'ops:alert-check', 'ops:data-export', 'ops:data-delete',
        'worker:outbox',
      ];

      for (const script of required) {
        assert.ok(pkg.scripts[script], `should have ${script} script`);
      }
    });

    it('has acceptance scripts', () => {
      const acceptance = [
        'ops:acceptance-evidence',
        'ops:acceptance-evidence:check',
        'ops:acceptance-preflight',
        'ops:acceptance-package',
        'ops:acceptance-status',
        'ops:acceptance-seal',
        'ops:acceptance-gate',
      ];

      for (const script of acceptance) {
        assert.ok(pkg.scripts[script], `should have ${script} script`);
      }
    });
  });

  describe('Script targets exist', () => {
    it('start script points to existing file', () => {
      const target = extractScriptTarget(pkg.scripts.start);
      if (target) {
        const filePath = path.join(repoRoot, target);
        assert.ok(fs.existsSync(filePath), `${target} should exist`);
      }
    });

    it('dev script points to existing file', () => {
      const target = extractScriptTarget(pkg.scripts.dev);
      if (target) {
        const filePath = path.join(repoRoot, target);
        assert.ok(fs.existsSync(filePath), `${target} should exist`);
      }
    });

    it('worker script points to existing file', () => {
      const target = extractScriptTarget(pkg.scripts['worker:outbox']);
      if (target) {
        const filePath = path.join(repoRoot, target);
        assert.ok(fs.existsSync(filePath), `${target} should exist`);
      }
    });

    it('db:seed script points to existing file', () => {
      const target = extractScriptTarget(pkg.scripts['db:seed']);
      if (target) {
        const filePath = path.join(repoRoot, target);
        assert.ok(fs.existsSync(filePath), `${target} should exist`);
      }
    });

    it('db:backup script points to existing file', () => {
      const target = extractScriptTarget(pkg.scripts['db:backup']);
      if (target) {
        const filePath = path.join(repoRoot, target);
        assert.ok(fs.existsSync(filePath), `${target} should exist`);
      }
    });

    it('db:restore script points to existing file', () => {
      const target = extractScriptTarget(pkg.scripts['db:restore']);
      if (target) {
        const filePath = path.join(repoRoot, target);
        assert.ok(fs.existsSync(filePath), `${target} should exist`);
      }
    });
  });

  describe('Ops script targets exist', () => {
    const opsScripts = [
      'ops:security-check',
      'ops:adapter-check',
      'ops:perf-smoke',
      'ops:perf-scenarios',
      'ops:alert-check',
    ];

    for (const script of opsScripts) {
      it(`${script} points to existing file`, () => {
        const target = extractScriptTarget(pkg.scripts[script]);
        if (target) {
          const filePath = path.join(repoRoot, target);
          assert.ok(fs.existsSync(filePath), `${target} should exist`);
        }
      });
    }
  });

  describe('Script consistency', () => {
    it('test:unit runs unit tests', () => {
      assert.ok(pkg.scripts['test:unit'].includes('unit'), 'test:unit should target unit tests');
    });

    it('test:integration runs integration tests', () => {
      assert.ok(pkg.scripts['test:integration'].includes('integration'), 'test:integration should target integration tests');
    });

    it('test:contract runs contract tests', () => {
      assert.ok(pkg.scripts['test:contract'].includes('contract'), 'test:contract should target contract tests');
    });

    it('lint runs eslint', () => {
      assert.ok(pkg.scripts.lint.includes('eslint'), 'lint should run eslint');
    });

    it('db:migrate uses prisma', () => {
      assert.ok(pkg.scripts['db:migrate'].includes('prisma'), 'db:migrate should use prisma');
    });

    it('db:deploy uses prisma migrate deploy', () => {
      assert.ok(pkg.scripts['db:deploy'].includes('prisma'), 'db:deploy should use prisma');
      assert.ok(pkg.scripts['db:deploy'].includes('deploy'), 'db:deploy should use deploy');
    });

    it('db:generate uses prisma generate', () => {
      assert.ok(pkg.scripts['db:generate'].includes('prisma'), 'db:generate should use prisma');
      assert.ok(pkg.scripts['db:generate'].includes('generate'), 'db:generate should use generate');
    });
  });

  describe('Dependencies', () => {
    it('has required production dependencies', () => {
      const deps = pkg.dependencies || {};
      assert.ok(deps['@prisma/client'], 'should have @prisma/client');
      assert.ok(deps.express, 'should have express');
      assert.ok(deps.jsonwebtoken, 'should have jsonwebtoken');
      assert.ok(deps.zod, 'should have zod');
      assert.ok(deps.pino, 'should have pino');
      assert.ok(deps.cors, 'should have cors');
      assert.ok(deps.dotenv, 'should have dotenv');
    });

    it('has required dev dependencies', () => {
      const devDeps = pkg.devDependencies || {};
      assert.ok(devDeps.prisma, 'should have prisma');
      assert.ok(devDeps.eslint, 'should have eslint');
    });

    it('has correct Node.js engine requirement', () => {
      assert.ok(pkg.engines, 'should have engines');
      assert.ok(pkg.engines.node, 'should have node engine');
      assert.ok(pkg.engines.node.includes('18'), 'should require Node 18+');
    });
  });

  describe('Package metadata', () => {
    it('has correct package name', () => {
      assert.equal(pkg.name, 'zhouyi-backend');
    });

    it('has correct version', () => {
      assert.ok(pkg.version, 'should have version');
    });

    it('has correct main entry point', () => {
      assert.equal(pkg.main, 'src/server.js');
    });

    it('has description', () => {
      assert.ok(pkg.description, 'should have description');
    });
  });
});

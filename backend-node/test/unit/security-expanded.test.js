const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..', '..');

describe('Security expanded checks (OPS-003)', () => {
  describe('Sensitive file protection', () => {
    it('.env is in .gitignore', () => {
      const gitignorePath = path.join(repoRoot, '..', '.gitignore');
      if (fs.existsSync(gitignorePath)) {
        const content = fs.readFileSync(gitignorePath, 'utf8');
        assert.ok(content.includes('.env'), '.env should be in .gitignore');
      }
    });

    it('uploads directory is in .gitignore', () => {
      const gitignorePath = path.join(repoRoot, '..', '.gitignore');
      if (fs.existsSync(gitignorePath)) {
        const content = fs.readFileSync(gitignorePath, 'utf8');
        assert.ok(content.includes('uploads'), 'uploads should be in .gitignore');
      }
    });

    it('backups directory is in .gitignore', () => {
      const gitignorePath = path.join(repoRoot, '..', '.gitignore');
      if (fs.existsSync(gitignorePath)) {
        const content = fs.readFileSync(gitignorePath, 'utf8');
        assert.ok(content.includes('backups'), 'backups should be in .gitignore');
      }
    });

    it('node_modules is in .gitignore', () => {
      const gitignorePath = path.join(repoRoot, '..', '.gitignore');
      if (fs.existsSync(gitignorePath)) {
        const content = fs.readFileSync(gitignorePath, 'utf8');
        assert.ok(content.includes('node_modules'), 'node_modules should be in .gitignore');
      }
    });
  });

  describe('No hardcoded secrets in source', () => {
    it('no hardcoded JWT secrets in source files', () => {
      const srcDir = path.join(repoRoot, 'src');
      const files = getAllJsFiles(srcDir);
      for (const file of files) {
        const content = fs.readFileSync(file, 'utf8');
        assert.ok(
          !content.includes('jwt_secret_value') && !content.includes('my-secret-key'),
          `${path.relative(repoRoot, file)} should not contain hardcoded JWT secrets`
        );
      }
    });

    it('no hardcoded database passwords in source files', () => {
      const srcDir = path.join(repoRoot, 'src');
      const files = getAllJsFiles(srcDir);
      for (const file of files) {
        const content = fs.readFileSync(file, 'utf8');
        assert.ok(
          !content.includes('password: ') || content.includes('password: process.env'),
          `${path.relative(repoRoot, file)} should not contain hardcoded passwords`
        );
      }
    });
  });

  describe('Environment variable validation', () => {
    it('.env.example exists as template', () => {
      const envExamplePath = path.join(repoRoot, '.env.example');
      assert.ok(fs.existsSync(envExamplePath), '.env.example should exist');
    });

    it('.env.example has required variables', () => {
      const envExamplePath = path.join(repoRoot, '.env.example');
      const content = fs.readFileSync(envExamplePath, 'utf8');
      assert.ok(content.includes('DATABASE_URL'), 'should document DATABASE_URL');
      assert.ok(content.includes('JWT_SECRET'), 'should document JWT_SECRET');
      assert.ok(content.includes('PORT'), 'should document PORT');
      assert.ok(content.includes('NODE_ENV'), 'should document NODE_ENV');
    });
  });

  describe('Dependency security', () => {
    it('package.json has no known vulnerable dependencies', () => {
      const pkg = JSON.parse(fs.readFileSync(path.join(repoRoot, 'package.json'), 'utf8'));
      const deps = { ...pkg.dependencies, ...pkg.devDependencies };
      // Check that we don't use known vulnerable packages
      const vulnerable = ['lodash', 'moment', 'request'];
      for (const vuln of vulnerable) {
        assert.ok(!deps[vuln], `should not use vulnerable package: ${vuln}`);
      }
    });

    it('package-lock.json exists for reproducible builds', () => {
      const lockPath = path.join(repoRoot, 'package-lock.json');
      assert.ok(fs.existsSync(lockPath), 'package-lock.json should exist');
    });
  });

  describe('Input validation', () => {
    it('Express app uses JSON body size limit', () => {
      const appPath = path.join(repoRoot, 'src', 'app.js');
      const content = fs.readFileSync(appPath, 'utf8');
      assert.ok(content.includes('limit'), 'should have body size limit');
    });

    it('CORS is configured', () => {
      const appPath = path.join(repoRoot, 'src', 'app.js');
      const content = fs.readFileSync(appPath, 'utf8');
      assert.ok(content.includes('cors'), 'should have CORS configured');
    });
  });

  describe('Authentication security', () => {
    it('JWT secret has minimum length requirement', () => {
      const envPath = path.join(repoRoot, 'src', 'config', 'env.js');
      const content = fs.readFileSync(envPath, 'utf8');
      assert.ok(content.includes('32'), 'should require JWT_SECRET >= 32 chars');
    });

    it('auth middleware exists', () => {
      const authPath = path.join(repoRoot, 'src', 'middleware', 'auth.js');
      assert.ok(fs.existsSync(authPath), 'auth middleware should exist');
    });

    it('rate limit middleware exists', () => {
      const rlPath = path.join(repoRoot, 'src', 'middleware', 'rate-limit.js');
      assert.ok(fs.existsSync(rlPath), 'rate limit middleware should exist');
    });

    it('idempotency middleware exists', () => {
      const idempPath = path.join(repoRoot, 'src', 'middleware', 'idempotency.js');
      assert.ok(fs.existsSync(idempPath), 'idempotency middleware should exist');
    });
  });

  describe('Error handling security', () => {
    it('error handler does not leak stack traces to client', () => {
      const errorHandlerPath = path.join(repoRoot, 'src', 'middleware', 'error-handler.js');
      const content = fs.readFileSync(errorHandlerPath, 'utf8');
      // Error handler should not send raw stack to client
      assert.ok(
        !content.includes('res.json({ stack') && !content.includes('err.stack'),
        'error handler should not leak stack traces'
      );
    });

    it('ApiError class exists for consistent error responses', () => {
      const apiErrorPath = path.join(repoRoot, 'src', 'shared', 'api-error.js');
      assert.ok(fs.existsSync(apiErrorPath), 'api-error.js should exist');
    });
  });

  describe('Logging security', () => {
    it('logger exists', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      assert.ok(fs.existsSync(loggerPath), 'logger.js should exist');
    });

    it('logger uses Pino', () => {
      const loggerPath = path.join(repoRoot, 'src', 'shared', 'logger.js');
      const content = fs.readFileSync(loggerPath, 'utf8');
      assert.ok(content.includes('pino'), 'should use Pino logger');
    });
  });
});

function getAllJsFiles(dir) {
  const files = [];
  if (!fs.existsSync(dir)) return files;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...getAllJsFiles(fullPath));
    } else if (entry.name.endsWith('.js')) {
      files.push(fullPath);
    }
  }
  return files;
}

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const specPath = path.join(__dirname, '..', '..', 'openapi', 'openapi.yaml');
const spec = fs.readFileSync(specPath, 'utf8');

function extractPaths(text) {
  const paths = [];
  const regex = /^ {2}(\/[a-z/{}_-]+):/gm;
  let match;
  while ((match = regex.exec(text)) !== null) {
    paths.push(match[1]);
  }
  return paths;
}

const paths = extractPaths(spec);

describe('OpenAPI compliance (FE-CONTRACT-001)', () => {
  describe('Spec structure', () => {
    it('uses OpenAPI 3.1.0', () => {
      assert.ok(spec.includes("openapi: '3.1.0'") || spec.includes('openapi: 3.1.0'), 'should use OpenAPI 3.1.0');
    });

    it('has required info fields', () => {
      assert.ok(spec.includes('title:'), 'should have title');
      assert.ok(spec.includes('version:'), 'should have version');
      assert.ok(spec.includes('description:'), 'should have description');
    });

    it('defines servers', () => {
      assert.ok(spec.includes('servers:'), 'should have servers');
      assert.ok(spec.includes('url:'), 'should have server url');
    });

    it('defines tags for API grouping', () => {
      assert.ok(spec.includes('tags:'), 'should have tags');
    });
  });

  describe('Path coverage', () => {
    it('defines health endpoint', () => {
      assert.ok(paths.includes('/health'), 'should have /health path');
    });

    it('defines auth endpoints', () => {
      assert.ok(paths.includes('/auth/phone/send-code'), 'should have send-code');
      assert.ok(paths.includes('/auth/phone/login'), 'should have login');
      assert.ok(paths.includes('/auth/session'), 'should have session');
      assert.ok(paths.includes('/auth/logout'), 'should have logout');
    });

    it('defines profile endpoints', () => {
      assert.ok(paths.includes('/profile/me'), 'should have /profile/me');
      assert.ok(paths.includes('/profile/me/settings'), 'should have settings');
      assert.ok(paths.includes('/profile/me/checkin'), 'should have checkin');
    });

    it('defines credit endpoints', () => {
      assert.ok(paths.includes('/credit/account'), 'should have /credit/account');
      assert.ok(paths.includes('/credit/consume'), 'should have /credit/consume');
    });

    it('defines billing endpoints', () => {
      assert.ok(paths.includes('/billing/plans'), 'should have /billing/plans');
      assert.ok(paths.includes('/billing/order/create'), 'should have order create');
    });

    it('defines ritual endpoints', () => {
      assert.ok(paths.includes('/ritual/perform'), 'should have /ritual/perform');
    });

    it('defines community endpoints', () => {
      assert.ok(paths.includes('/community/feed'), 'should have /community/feed');
      assert.ok(paths.includes('/community/post'), 'should have /community/post');
    });

    it('defines notification endpoints', () => {
      assert.ok(paths.includes('/notifications'), 'should have /notifications');
      assert.ok(paths.includes('/notifications/unread-count'), 'should have unread-count');
    });

    it('defines match endpoints', () => {
      assert.ok(paths.includes('/match/same-frequency'), 'should have same-frequency');
      assert.ok(paths.includes('/match/radar/status'), 'should have radar status');
    });

    it('defines activity endpoints', () => {
      assert.ok(paths.includes('/activities/list'), 'should have activities list');
    });

    it('defines share endpoints', () => {
      assert.ok(paths.includes('/share/card/save'), 'should have share card save');
      assert.ok(paths.includes('/share/card/render'), 'should have share card render');
    });

    it('defines analytics endpoints', () => {
      assert.ok(paths.includes('/analytics/events'), 'should have analytics events');
      assert.ok(paths.includes('/analytics/wmru'), 'should have WMRU metric');
    });

    it('defines admin endpoints', () => {
      assert.ok(
        paths.some((p) => p.includes('admin')),
        'should have admin paths'
      );
    });
  });

  describe('Response envelope', () => {
    it('spec defines success envelope format', () => {
      assert.ok(spec.includes('"success": true'), 'should define success envelope');
      assert.ok(spec.includes('"data"'), 'should define data field');
    });

    it('spec defines error envelope format', () => {
      assert.ok(spec.includes('"success": false'), 'should define error envelope');
      assert.ok(spec.includes('"error"'), 'should define error field');
    });

    it('spec defines error codes', () => {
      assert.ok(spec.includes('40001'), 'should define parameter error code');
      assert.ok(spec.includes('40101'), 'should define auth error code');
      assert.ok(spec.includes('40401'), 'should define not found error code');
      assert.ok(spec.includes('50000'), 'should define internal error code');
    });
  });

  describe('Authentication', () => {
    it('spec defines Bearer token authentication', () => {
      assert.ok(spec.includes('Bearer Token') || spec.includes('bearerAuth'), 'should define Bearer auth');
    });

    it('spec defines security schemes', () => {
      assert.ok(spec.includes('securitySchemes:'), 'should have security schemes');
    });
  });

  describe('Pagination', () => {
    it('spec defines pagination parameters', () => {
      assert.ok(spec.includes('page'), 'should have page parameter');
      assert.ok(spec.includes('pageSize'), 'should have pageSize parameter');
    });

    it('spec defines pagination response', () => {
      assert.ok(spec.includes('hasMore'), 'should define hasMore field');
    });
  });

  describe('Idempotency', () => {
    it('spec defines idempotency support', () => {
      assert.ok(spec.includes('Idempotency-Key'), 'should define Idempotency-Key header');
    });
  });

  describe('Total path count', () => {
    it('has at least 30 API paths', () => {
      assert.ok(paths.length >= 30, `Expected at least 30 paths, got ${paths.length}`);
    });
  });
});

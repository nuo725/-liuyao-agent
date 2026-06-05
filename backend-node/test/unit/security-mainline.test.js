// Security Mainline Tests (TEST-002)
// Covers auth failure, authorization, idempotency replay, media validation,
// private interpretation leakage, and community moderation bypass checks.

process.env.NODE_ENV = process.env.NODE_ENV || 'test';
process.env.DATABASE_URL = process.env.DATABASE_URL || 'postgresql://test:test@localhost:5432/test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_for_security_mainline_32_chars';
process.env.JWT_ACCESS_TTL = process.env.JWT_ACCESS_TTL || '7200';
process.env.JWT_REFRESH_TTL = process.env.JWT_REFRESH_TTL || '2592000';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const jwt = require('jsonwebtoken');
const { requestIdMiddleware } = require('../../src/middleware/request-id');
const { errorHandler } = require('../../src/middleware/error-handler');
const { requireAuth } = require('../../src/middleware/auth');
const { idempotency } = require('../../src/middleware/idempotency');
const { uploadMedia } = require('../../src/modules/media/service');
const { assessPostPayload } = require('../../src/modules/community/moderation');
const { startTestApp, stopTestApp } = require('../helpers/http');
const { assertFailEnvelope } = require('../helpers/setup');

function createMiddlewareApp(registerRoutes) {
  const app = express();
  app.use(express.json());
  app.use(requestIdMiddleware);
  registerRoutes(app);
  app.use(errorHandler);
  return app;
}

function withPrismaStub(prismaStub) {
  const prismaPath = require.resolve('../../src/db/prisma');
  const authPath = require.resolve('../../src/middleware/auth');
  const prismaModule = require(prismaPath);
  const originalGetPrisma = prismaModule.getPrisma;

  prismaModule.getPrisma = () => prismaStub;
  delete require.cache[authPath];
  const authModule = require('../../src/middleware/auth');

  return {
    authModule,
    restore() {
      prismaModule.getPrisma = originalGetPrisma;
      delete require.cache[authPath];
    },
  };
}

describe('Security mainline', () => {
  describe('auth and authorization', () => {
    let server, client;

    before(async () => {
      const app = createMiddlewareApp((router) => {
        router.get('/private', requireAuth, (_req, res) => {
          res.json({ success: true, data: { ok: true } });
        });
      });
      ({ server, client } = await startTestApp(app));
    });

    after(async () => {
      await stopTestApp(server);
    });

    it('rejects requests without token', async () => {
      const res = await client.get('/private');
      assert.equal(res.status, 401);
      assertFailEnvelope({ assert: assert.ok }, res.body, '40101');
    });

    it('rejects expired tokens', async () => {
      const expiredToken = jwt.sign({ sub: 'user_expired' }, process.env.JWT_SECRET, {
        expiresIn: -1,
      });
      const res = await client.get('/private', {
        headers: { Authorization: `Bearer ${expiredToken}` },
      });
      assert.equal(res.status, 401);
      assertFailEnvelope({ assert: assert.ok }, res.body, '40102');
    });
  });

  it('rejects insufficient role access', async () => {
    const prismaStub = {
      user: {
        findUnique: async () => ({ role: 'user', status: 'active' }),
      },
    };
    const { authModule, restore } = withPrismaStub(prismaStub);

    const app = createMiddlewareApp((router) => {
      router.get(
        '/admin',
        (req, _res, next) => {
          req.userId = 'user_regular';
          next();
        },
        authModule.requireRole('admin'),
        (_req, res) => {
          res.json({ success: true, data: { ok: true } });
        }
      );
    });

    const { server, client } = await startTestApp(app);
    try {
      const res = await client.get('/admin');
      assert.equal(res.status, 403);
      assertFailEnvelope({ assert: assert.ok }, res.body, '40301');
    } finally {
      await stopTestApp(server);
      restore();
    }
  });

  it('replays successful write responses by Idempotency-Key', async () => {
    let calls = 0;
    const idempotencyKey = `security-replay-${Date.now()}`;
    const app = createMiddlewareApp((router) => {
      router.post(
        '/write',
        (req, _res, next) => {
          req.userId = 'user_idempotent';
          next();
        },
        idempotency,
        (req, res) => {
          calls += 1;
          res.status(201).json({
            success: true,
            data: {
              calls,
              value: req.body.value,
            },
          });
        }
      );
    });

    const { server, client } = await startTestApp(app);
    try {
      const first = await client.post('/write', {
        headers: { 'Idempotency-Key': idempotencyKey },
        body: { value: 'first' },
      });
      const second = await client.post('/write', {
        headers: { 'Idempotency-Key': idempotencyKey },
        body: { value: 'second' },
      });

      assert.equal(first.status, 201);
      assert.equal(second.status, 201);
      assert.equal(first.body.data.calls, 1);
      assert.equal(second.body.data.calls, 1);
      assert.equal(second.body.data.value, 'first');
      assert.equal(calls, 1);
    } finally {
      await stopTestApp(server);
    }
  });

  it('rejects illegal media upload metadata before persistence', async () => {
    await assert.rejects(
      () =>
        uploadMedia('user_media', {
          headers: { 'content-type': 'application/json' },
          body: {
            purpose: 'post',
            url: 'https://cdn.example.com/not-image.txt',
            mime: 'text/plain',
            size: 128,
          },
        }),
      (err) => err.code === '40001' && /jpeg|png|webp|gif/i.test(err.message)
    );
  });

  it('does not assess private interpretation content for public community publishing', () => {
    const assessment = assessPostPayload({
      shareText: '今天慢慢整理了一下关系里的边界。',
      card: {
        riskLevel: 'low',
        privateContent: {
          summary: 'private phone 13800138000 should never enter community review text',
        },
        communitySafeContent: {
          summary: '公开摘要只保留安全表达。',
          body: '一段不包含私密信息的公开复盘。',
        },
      },
    });

    assert.equal(assessment.decision, 'approve');
    assert.equal(assessment.riskLevel, 'low');
    assert.deepEqual(assessment.categories, []);
  });

  it('blocks moderation bypass attempts with spam and private contact data', () => {
    const assessment = assessPostPayload({
      shareText: '加微 13800138000 返利刷单，马上联系。',
      card: null,
    });

    assert.equal(assessment.decision, 'remove');
    assert.equal(assessment.riskLevel, 'high');
    assert.ok(assessment.categories.includes('spam'));
    assert.ok(assessment.categories.includes('privacy_phone'));
  });

  it('limits high-risk interpretation cards even when share text looks safe', () => {
    const assessment = assessPostPayload({
      shareText: '想分享一点温和的复盘。',
      card: {
        riskLevel: 'high',
        communitySafeContent: {
          summary: '公开摘要本身看起来安全。',
        },
      },
    });

    assert.equal(assessment.decision, 'limit');
    assert.equal(assessment.riskLevel, 'medium');
    assert.ok(assessment.categories.includes('card_high_risk'));
  });
});

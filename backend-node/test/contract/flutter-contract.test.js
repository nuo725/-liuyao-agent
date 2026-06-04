// Contract Regression Test (OPS-008)
// Verifies that the API responses match what the Flutter frontend expects.
// Covers the main user flows: auth → ritual → community → notifications.

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createTestApp } = require('../helpers/setup');
const { startTestApp, stopTestApp } = require('../helpers/http');

describe('Flutter Contract Regression', () => {
  let server, client;
  let accessToken;

  before(async () => {
    const app = createTestApp();
    ({ server, client } = await startTestApp(app));

    // Login to get a token (test mode: code is 123456)
    const sendRes = await client.post('/api/v1/auth/phone/send-code', {
      body: { phone: '13800000000' },
    });
    assert.equal(sendRes.status, 200);

    const loginRes = await client.post('/api/v1/auth/phone/login', {
      body: { phone: '13800000000', code: '123456' },
    });
    assert.equal(loginRes.status, 200);
    accessToken = loginRes.body.data.accessToken;
  });

  after(async () => {
    await stopTestApp(server);
  });

  function authHeader() {
    return { headers: { Authorization: `Bearer ${accessToken}` } };
  }

  // ─────── Auth Flow ───────

  describe('Auth Flow', () => {
    it('POST /auth/phone/send-code returns success', async () => {
      const res = await client.post('/api/v1/auth/phone/send-code', {
        body: { phone: '13800000001' },
      });
      assert.equal(res.status, 200);
      assert.equal(res.body.success, true);
    });

    it('POST /auth/phone/login returns user + tokens', async () => {
      const res = await client.post('/api/v1/auth/phone/login', {
        body: { phone: '13800000001', code: '123456' },
      });
      assert.equal(res.status, 200);
      assert.ok(res.body.data.accessToken, 'expected accessToken');
      assert.ok(res.body.data.refreshToken, 'expected refreshToken');
      assert.ok(res.body.data.user, 'expected user object');
      assert.ok(res.body.data.user.id, 'expected user.id');
      assert.ok(res.body.data.user.username, 'expected user.username');
    });

    it('GET /auth/session returns user profile', async () => {
      const res = await client.get('/api/v1/auth/session', authHeader());
      assert.equal(res.status, 200);
      assert.ok(res.body.data.user, 'expected user');
      assert.ok(res.body.data.user.id, 'expected user.id');
    });
  });

  // ─────── Profile Flow ───────

  describe('Profile Flow', () => {
    it('GET /profile/me returns profile with settings', async () => {
      const res = await client.get('/api/v1/profile/me', authHeader());
      assert.equal(res.status, 200);
      assert.ok(res.body.data.id, 'expected id');
      assert.ok(res.body.data.username, 'expected username');
    });

    it('PUT /profile/me updates profile', async () => {
      const res = await client.put('/api/v1/profile/me', {
        ...authHeader(),
        body: { bio: '测试简介' },
      });
      assert.equal(res.status, 200);
      assert.equal(res.body.data.bio, '测试简介');
    });

    it('GET /profile/me/settings returns settings object', async () => {
      const res = await client.get('/api/v1/profile/me/settings', authHeader());
      assert.equal(res.status, 200);
      assert.ok(typeof res.body.data.pushEnabled === 'boolean', 'expected pushEnabled');
    });
  });

  // ─────── Credits Flow ───────

  describe('Credits Flow', () => {
    it('GET /credit/account returns credit balances', async () => {
      const res = await client.get('/api/v1/credit/account', authHeader());
      assert.equal(res.status, 200);
      assert.ok(typeof res.body.data.castBalance === 'number', 'expected castBalance');
      assert.ok(typeof res.body.data.followupBalance === 'number', 'expected followupBalance');
      assert.ok(typeof res.body.data.isVip === 'boolean', 'expected isVip');
    });
  });

  // ─────── Ritual Flow ───────

  describe('Ritual Flow', () => {
    let sessionId;

    it('POST /ritual/perform creates a session', async () => {
      const res = await client.post('/api/v1/ritual/perform', {
        ...authHeader(),
        body: {
          question: '最近工作上有些迷茫',
          tag: 'career',
          lines: [0, 1, 0, 1, 1, 0],
          movingLines: [1, 4],
        },
      });
      assert.equal(res.status, 200);
      assert.ok(res.body.data.sessionId, 'expected sessionId');
      assert.equal(res.body.data.tag, 'career');
      assert.ok(res.body.data.pattern, 'expected pattern');
      sessionId = res.body.data.sessionId;
    });

    it('GET /ritual/session/:id restores session', async () => {
      const res = await client.get(`/api/v1/ritual/session/${sessionId}`, authHeader());
      assert.equal(res.status, 200);
      assert.equal(res.body.data.sessionId, sessionId);
      assert.equal(res.body.data.tag, 'career');
    });

    it('GET /ritual/session/:id/preview works without auth', async () => {
      const res = await client.get(`/api/v1/ritual/session/${sessionId}/preview`);
      assert.equal(res.status, 200);
      assert.equal(res.body.data.sessionId, sessionId);
    });

    it('POST /ritual/session/:id/continue adds follow-up', async () => {
      const res = await client.post(`/api/v1/ritual/session/${sessionId}/continue`, {
        ...authHeader(),
        body: { message: '我应该怎么判断？' },
      });
      assert.equal(res.status, 200);
      assert.ok(res.body.data.id, 'expected message id');
      assert.equal(res.body.data.type, 'question');
    });

    it('GET /ritual/session/:id/chat-history returns messages', async () => {
      const res = await client.get(`/api/v1/ritual/session/${sessionId}/chat-history`, authHeader());
      assert.equal(res.status, 200);
      assert.ok(Array.isArray(res.body.data.messages), 'expected messages array');
    });

    it('GET /ritual/user/:id/completion-today returns status', async () => {
      const res = await client.get('/api/v1/ritual/user/user_demo/completion-today', authHeader());
      assert.equal(res.status, 200);
      assert.ok(typeof res.body.data.completed === 'boolean', 'expected completed');
      assert.ok(res.body.data.dateKey, 'expected dateKey');
    });
  });

  // ─────── Community Flow ───────

  describe('Community Flow', () => {
    let postId;

    it('GET /community/feed returns paginated items', async () => {
      const res = await client.get('/api/v1/community/feed?tab=recommended&page=1&pageSize=10');
      assert.equal(res.status, 200);
      assert.ok(Array.isArray(res.body.data.items), 'expected items array');
      assert.ok(typeof res.body.data.hasMore === 'boolean', 'expected hasMore');
    });

    it('POST /community/post creates a post', async () => {
      const res = await client.post('/api/v1/community/post', {
        ...authHeader(),
        body: { shareText: '测试帖子内容' },
      });
      assert.equal(res.status, 200);
      assert.ok(res.body.data.id, 'expected post id');
      postId = res.body.data.id;
    });

    it('GET /community/post/:id returns post detail', async () => {
      const res = await client.get(`/api/v1/community/post/${postId}`);
      assert.equal(res.status, 200);
      assert.equal(res.body.data.id, postId);
      assert.ok(res.body.data.metrics, 'expected metrics');
      assert.ok(typeof res.body.data.metrics.likes === 'number', 'expected likes count');
    });

    it('POST /community/post/:id/like is idempotent', async () => {
      const res1 = await client.post(`/api/v1/community/post/${postId}/like`, authHeader());
      assert.equal(res1.status, 200);
      assert.equal(res1.body.data.liked, true);

      const res2 = await client.post(`/api/v1/community/post/${postId}/like`, authHeader());
      assert.equal(res2.status, 200);
      assert.equal(res2.body.data.liked, true);
    });

    it('POST /community/post/:id/comments creates comment', async () => {
      const res = await client.post(`/api/v1/community/post/${postId}/comments`, {
        ...authHeader(),
        body: { text: '测试评论' },
      });
      assert.equal(res.status, 200);
      assert.ok(res.body.data.id, 'expected comment id');
      assert.equal(res.body.data.text, '测试评论');
    });

    it('GET /community/post/:id/comments returns comment list', async () => {
      const res = await client.get(`/api/v1/community/post/${postId}/comments?page=1&pageSize=10`);
      assert.equal(res.status, 200);
      assert.ok(Array.isArray(res.body.data.items), 'expected items');
    });

    it('GET /community/search returns results', async () => {
      const res = await client.get('/api/v1/community/search?q=测试&type=post');
      assert.equal(res.status, 200);
      assert.ok(Array.isArray(res.body.data.items), 'expected items');
    });
  });

  // ─────── Notification Flow ───────

  describe('Notification Flow', () => {
    it('GET /notifications returns paginated list', async () => {
      const res = await client.get('/api/v1/notifications', authHeader());
      assert.equal(res.status, 200);
      assert.ok(Array.isArray(res.body.data.items), 'expected items');
      assert.ok(typeof res.body.data.unreadCount === 'number', 'expected unreadCount');
    });

    it('GET /notifications/unread-count returns count', async () => {
      const res = await client.get('/api/v1/notifications/unread-count', authHeader());
      assert.equal(res.status, 200);
      assert.ok(typeof res.body.data.count === 'number', 'expected count');
    });
  });

  // ─────── Response Envelope ───────

  describe('Response Envelope', () => {
    it('success response has { success: true, data }', async () => {
      const res = await client.get('/api/v1/health');
      assert.equal(res.body.success, true);
      assert.ok(res.body.data !== undefined, 'expected data field');
    });

    it('error response has { success: false, error: { code, message } }', async () => {
      const res = await client.get('/api/v1/nonexistent');
      assert.equal(res.body.success, false);
      assert.ok(res.body.error, 'expected error field');
      assert.ok(res.body.error.code, 'expected error.code');
      assert.ok(res.body.error.message, 'expected error.message');
    });

    it('all responses include X-Request-Id header', async () => {
      const res = await client.get('/api/v1/health');
      const requestId = res.headers.get('x-request-id');
      assert.ok(requestId, 'expected X-Request-Id');
      assert.ok(requestId.startsWith('req_'), 'expected req_ prefix');
    });
  });
});

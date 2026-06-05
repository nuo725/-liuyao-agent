// API Mainline Integration Tests (TEST-001)
// Runs the real Express app and route middleware with service-layer stubs so
// core HTTP contracts can be verified without a PostgreSQL test database.

process.env.NODE_ENV = 'test';
process.env.RATE_LIMIT_STORE = 'memory';
process.env.DATABASE_URL = process.env.DATABASE_URL || 'postgresql://test:test@localhost:5432/test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_for_api_mainline_32_chars';
process.env.JWT_ACCESS_TTL = process.env.JWT_ACCESS_TTL || '7200';
process.env.JWT_REFRESH_TTL = process.env.JWT_REFRESH_TTL || '2592000';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const path = require('node:path');
const { startTestApp, stopTestApp } = require('../helpers/http');
const { assertOkEnvelope } = require('../helpers/setup');

const repoRoot = path.join(__dirname, '..', '..');
const apiUserId = 'user_api_mainline';

function modulePath(relativePath) {
  return path.join(repoRoot, relativePath);
}

function stubModule(relativePath, exportsObject) {
  const resolved = require.resolve(modulePath(relativePath));
  require.cache[resolved] = {
    id: resolved,
    filename: resolved,
    loaded: true,
    exports: exportsObject,
  };
}

function clearAppAndRoutes() {
  const paths = [
    'src/app.js',
    'src/modules/auth/route.js',
    'src/modules/profile/route.js',
    'src/modules/credits/route.js',
    'src/modules/billing/route.js',
    'src/modules/ritual/route.js',
    'src/modules/community/route.js',
    'src/modules/notifications/route.js',
    'src/modules/match/route.js',
    'src/modules/activities/route.js',
    'src/modules/media/route.js',
  ];
  for (const relativePath of paths) {
    const resolved = require.resolve(modulePath(relativePath));
    delete require.cache[resolved];
  }
}

function installServiceStubs() {
  stubModule('src/modules/auth/service.js', {
    sendVerificationCode: async (phone) => ({ phone, sent: true }),
    phoneLogin: async (phone) => ({
      user: { id: apiUserId, phone },
      accessToken: signToken(apiUserId),
      refreshToken: 'refresh_api_mainline',
    }),
    socialLogin: async (provider) => ({ provider, user: { id: apiUserId } }),
    restoreSession: async (userId) => ({ user: { id: userId, username: 'API User' } }),
    refreshSession: async () => ({ accessToken: signToken(apiUserId) }),
    logout: async () => ({ loggedOut: true }),
    upgradeGuest: async (userId, phone) => ({ userId, phone, upgraded: true }),
  });

  stubModule('src/modules/profile/service.js', {
    getPublicProfile: async (shortId, viewerId) => ({ shortId, viewerId, publicProfile: true }),
    getMyProfile: async (userId) => ({ id: userId, username: 'API User' }),
    updateMyProfile: async (userId, patch) => ({ id: userId, ...patch }),
    requestDeleteAccount: async (userId) => ({ userId, status: 'pending_deletion' }),
    getMySettings: async (userId) => ({ userId, pushEnabled: true }),
    updateMySettings: async (_userId, settings) => settings,
    getCheckinCalendar: async () => ({ items: [] }),
    checkin: async () => ({ checkedIn: true }),
    getInteractions: async () => ({ items: [], page: 1, pageSize: 20 }),
    getBrowseHistory: async () => ({ items: [], page: 1, pageSize: 20 }),
    updateAvatar: async (_userId, mediaId) => ({ mediaId }),
    updateCover: async (_userId, mediaId) => ({ mediaId }),
    getShareCard: async (userId) => ({ userId, url: 'https://example.com/share/api-user' }),
  });

  stubModule('src/modules/profile/anonymous-service.js', {
    getOrCreateProfile: async (userId) => ({ userId, nickname: '匿名回声' }),
    updateProfile: async (_userId, patch) => patch,
    createAnonymousPost: async (userId, body) => ({ userId, postId: 'post_anonymous', ...body }),
  });

  stubModule('src/modules/credits/service.js', {
    getAccount: async (userId) => ({ userId, castBalance: 3, followupBalance: 5, isVip: false }),
    consume: async (userId, type, amount) => ({ userId, type, amount, remaining: 2 }),
    resetDaily: async (userId) => ({ userId, reset: true }),
  });

  stubModule('src/modules/billing/service.js', {
    listPlans: async () => ({ items: [{ id: 'vip_monthly', price: 1900 }] }),
    createOrder: async (userId, planId) => ({ orderId: 'order_api_mainline', userId, planId }),
    confirmPayment: async (_userId, orderId) => ({ orderId, status: 'paid' }),
    getOrder: async (_userId, orderId) => ({ orderId, status: 'pending' }),
  });

  stubModule('src/modules/ritual/service.js', {
    perform: async (userId, question, tag, lines, movingLines) => ({
      sessionId: 'ritual_api_mainline',
      userId,
      question,
      tag,
      pattern: { lines, movingLines },
      status: 'active',
    }),
    getSession: async (sessionId, userId) => ({ sessionId, userId, status: 'active' }),
    getPreview: async (sessionId) => ({ sessionId, preview: true }),
    getFullInterpretation: async (sessionId) => ({ sessionId, privateContent: { summary: 'stub' } }),
    addFollowup: async (sessionId, userId, message) => ({ sessionId, userId, message }),
    getChatHistory: async (sessionId) => ({ sessionId, items: [] }),
    getCompletionToday: async (userId) => ({ userId, completed: true }),
    saveEmotionCalibration: async (sessionId, userId, body) => ({ sessionId, userId, ...body }),
    getPeriodicReview: async (userId, days) => ({ userId, days, themes: [] }),
  });

  stubModule('src/modules/community/service.js', {
    getFeed: async (tab, page, pageSize, viewerId) => ({ tab, page, pageSize, viewerId, items: [] }),
    getPostDetail: async (postId) => ({ id: postId, shareText: 'detail' }),
    getComments: async (postId) => ({ postId, items: [] }),
    createComment: async (postId, userId, text) => ({ id: 'comment_api_mainline', postId, userId, text }),
    createPost: async (userId, body) => ({ id: 'post_api_mainline', userId, ...body }),
    likePost: async (postId) => ({ postId, liked: true }),
    unlikePost: async (postId) => ({ postId, liked: false }),
    favoritePost: async (postId) => ({ postId, favorited: true }),
    unfavoritePost: async (postId) => ({ postId, favorited: false }),
    reportPost: async (postId) => ({ postId, reported: true }),
    hidePost: async (postId) => ({ postId, hidden: true }),
    getAuthorProfile: async (authorId) => ({ authorId }),
    followAuthor: async (_userId, authorId) => ({ authorId, following: true }),
    unfollowAuthor: async (_userId, authorId) => ({ authorId, following: false }),
    blockUser: async (_userId, authorId) => ({ authorId, blocked: true }),
    unblockUser: async (_userId, authorId) => ({ authorId, blocked: false }),
    search: async (q, type) => ({ q, type, items: [] }),
    listModerationQueue: async () => ({ items: [] }),
    handleModerationTarget: async () => ({ handled: true }),
    handleReport: async () => ({ handled: true }),
  });

  stubModule('src/modules/notifications/service.js', {
    listNotifications: async (userId) => ({ userId, items: [] }),
    getUnreadCount: async (userId) => ({ userId, count: 2 }),
    markRead: async (_userId, id) => ({ id, read: true }),
    markAllRead: async (userId) => ({ userId, readAll: true }),
    dismiss: async (_userId, id) => ({ id, dismissed: true }),
    registerToken: async (_userId, token, platform) => ({ token, platform }),
    unregisterToken: async (_userId, token) => ({ token, removed: true }),
    syncState: async (_userId, readIds, dismissedIds) => ({ readIds, dismissedIds }),
    sendSystemNotification: async () => ({ sent: true }),
  });

  stubModule('src/modules/match/service.js', {
    unlock: async (userId, deviceId) => ({ userId, deviceId, unlocked: true }),
    getSameFrequency: async (userId, tab) => ({ userId, tab, items: [] }),
    getRadarStatus: async (userId) => ({ userId, unlockedToday: true }),
  });

  stubModule('src/modules/activities/service.js', {
    listActivities: async (page, pageSize, viewerId) => ({ page, pageSize, viewerId, items: [] }),
    getActivityDetail: async (id) => ({ id, title: 'API Activity' }),
    joinActivity: async (id, userId) => ({ id, userId, status: 'joined' }),
    getJoinStatus: async (id, userId) => ({ id, userId, status: 'joined' }),
    createActivity: async (body, operatorId) => ({ id: 'activity_created', operatorId, ...body }),
    updateActivity: async (id, body) => ({ id, ...body }),
  });

  stubModule('src/modules/media/service.js', {
    uploadMedia: async (userId, req) => ({
      id: 'media_api_mainline',
      ownerId: userId,
      url: req.body.url,
      purpose: req.body.purpose,
      mime: req.body.mime,
      size: req.body.size,
      status: 'ready',
    }),
  });
}

function signToken(userId = apiUserId) {
  return jwt.sign({ sub: userId }, process.env.JWT_SECRET, { expiresIn: '2h' });
}

function authHeaders(extra = {}) {
  return {
    Authorization: `Bearer ${signToken()}`,
    ...extra,
  };
}

async function expectOk(response, status = 200) {
  assert.equal(response.status, status);
  assertOkEnvelope({ assert: assert.ok }, response.body);
  return response.body.data;
}

describe('API mainline integration', () => {
  let server, client;

  before(async () => {
    clearAppAndRoutes();
    installServiceStubs();
    clearAppAndRoutes();
    const { createApp } = require('../../src/app');
    ({ server, client } = await startTestApp(createApp()));
  });

  after(async () => {
    await stopTestApp(server);
  });

  it('covers auth login and session restore', async () => {
    const login = await expectOk(
      await client.post('/api/v1/auth/phone/login', {
        headers: { 'Idempotency-Key': 'api-mainline-login' },
        body: {
          phone: '13800138000',
          code: '123456',
          agreementVersion: '2026-06-05',
          privacyVersion: '2026-06-05',
          consentedAt: '2026-06-05T00:00:00.000Z',
        },
      })
    );
    assert.equal(login.user.id, apiUserId);

    const session = await expectOk(
      await client.get('/api/v1/auth/session', {
        headers: authHeaders(),
      })
    );
    assert.equal(session.user.id, apiUserId);
  });

  it('covers profile, credits, billing, media, and notification APIs', async () => {
    const profile = await expectOk(await client.get('/api/v1/profile/me', { headers: authHeaders() }));
    assert.equal(profile.id, apiUserId);

    const credits = await expectOk(await client.get('/api/v1/credits/account', { headers: authHeaders() }));
    assert.equal(credits.castBalance, 3);

    const plans = await expectOk(await client.get('/api/v1/billing/plans', { headers: authHeaders() }));
    assert.equal(plans.items[0].id, 'vip_monthly');

    const order = await expectOk(
      await client.post('/api/v1/billing/order/create', {
        headers: authHeaders({ 'Idempotency-Key': 'api-mainline-order' }),
        body: { planId: 'vip_monthly' },
      })
    );
    assert.equal(order.orderId, 'order_api_mainline');

    const media = await expectOk(
      await client.post('/api/v1/media/upload', {
        headers: authHeaders(),
        body: {
          purpose: 'post',
          url: 'https://cdn.example.com/api-mainline.png',
          mime: 'image/png',
          size: 1024,
        },
      })
    );
    assert.equal(media.id, 'media_api_mainline');

    const unread = await expectOk(await client.get('/api/v1/notifications/unread-count', { headers: authHeaders() }));
    assert.equal(unread.count, 2);
  });

  it('covers ritual, community, match, and activity APIs', async () => {
    const ritual = await expectOk(
      await client.post('/api/v1/ritual/perform', {
        headers: authHeaders({ 'Idempotency-Key': 'api-mainline-ritual' }),
        body: {
          question: '我该如何整理这段关系？',
          tag: 'relationship',
          lines: [0, 1, 0, 1, 0, 1],
          movingLines: [1, 4],
        },
      })
    );
    assert.equal(ritual.sessionId, 'ritual_api_mainline');

    const feed = await expectOk(await client.get('/api/v1/community/feed?tab=recommended&page=1&pageSize=10'));
    assert.equal(feed.tab, 'recommended');

    const post = await expectOk(
      await client.post('/api/v1/community/post', {
        headers: authHeaders({ 'Idempotency-Key': 'api-mainline-post' }),
        body: { shareText: '今天有一点新的整理。' },
      })
    );
    assert.equal(post.id, 'post_api_mainline');

    const radar = await expectOk(await client.get('/api/v1/match/radar/status', { headers: authHeaders() }));
    assert.equal(radar.unlockedToday, true);

    const activities = await expectOk(await client.get('/api/v1/activities/list?page=1&pageSize=10'));
    assert.deepEqual(activities.items, []);

    const join = await expectOk(
      await client.post('/api/v1/activities/activity_api_mainline/join', {
        headers: authHeaders({ 'Idempotency-Key': 'api-mainline-join' }),
      })
    );
    assert.equal(join.status, 'joined');
  });
});

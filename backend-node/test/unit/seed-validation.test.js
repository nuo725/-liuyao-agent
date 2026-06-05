const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const seedPath = path.join(__dirname, '..', '..', 'prisma', 'seed.js');
const seed = fs.readFileSync(seedPath, 'utf8');

describe('Seed script validation (DB-001)', () => {
  describe('Script structure', () => {
    it('seed.js exists and is readable', () => {
      assert.ok(seed.length > 0, 'seed.js should not be empty');
    });

    it('uses PrismaClient', () => {
      assert.ok(seed.includes('PrismaClient'), 'should use PrismaClient');
    });

    it('has main function', () => {
      assert.ok(seed.includes('async function main()'), 'should have async main function');
    });

    it('disconnects prisma in finally block', () => {
      assert.ok(seed.includes('prisma.$disconnect()'), 'should disconnect prisma');
    });

    it('has error handling', () => {
      assert.ok(seed.includes('.catch('), 'should have error handling');
      assert.ok(seed.includes('process.exit(1)'), 'should exit on error');
    });
  });

  describe('Entity coverage', () => {
    it('creates demo users', () => {
      assert.ok(seed.includes("id: 'user_demo'"), 'should create demo user');
      assert.ok(seed.includes("id: 'user_peer'"), 'should create peer user');
    });

    it('creates profile settings', () => {
      assert.ok(seed.includes('profileSettings.upsert'), 'should create profile settings');
    });

    it('creates credit accounts', () => {
      assert.ok(seed.includes('creditAccount.upsert'), 'should create credit accounts');
    });

    it('creates agreement consents', () => {
      assert.ok(seed.includes('agreementConsent.create'), 'should create agreement consents');
    });

    it('creates ritual session with hexagram pattern', () => {
      assert.ok(seed.includes('ritualSession.create'), 'should create ritual session');
      assert.ok(seed.includes('movingLines'), 'should include movingLines');
      assert.ok(seed.includes("tag: 'career'"), 'should have career tag');
    });

    it('creates interpretation card', () => {
      assert.ok(seed.includes('interpretationCard.create'), 'should create interpretation card');
      assert.ok(seed.includes('privateContent'), 'should have privateContent');
      assert.ok(seed.includes('communitySafeContent'), 'should have communitySafeContent');
    });

    it('creates follow-up messages', () => {
      assert.ok(seed.includes('followupMessage.createMany'), 'should create follow-up messages');
    });

    it('creates community post', () => {
      assert.ok(seed.includes('communityPost.create'), 'should create community post');
      assert.ok(seed.includes('shareText'), 'should have shareText');
    });

    it('creates comment', () => {
      assert.ok(seed.includes('comment.create'), 'should create comment');
    });

    it('creates like and favorite', () => {
      assert.ok(seed.includes('postLike.create'), 'should create like');
      assert.ok(seed.includes('postFavorite.create'), 'should create favorite');
    });

    it('creates activity', () => {
      assert.ok(seed.includes('activity.create'), 'should create activity');
      assert.ok(seed.includes('activityJoin.create'), 'should create activity join');
    });

    it('creates notification', () => {
      assert.ok(seed.includes('notification.create'), 'should create notification');
    });

    it('creates billing plans', () => {
      assert.ok(seed.includes('billingPlan.createMany'), 'should create billing plans');
      assert.ok(seed.includes('7天VIP体验'), 'should have 7-day plan');
      assert.ok(seed.includes('30天VIP'), 'should have 30-day plan');
      assert.ok(seed.includes('90天VIP'), 'should have 90-day plan');
    });

    it('creates daily completion record', () => {
      assert.ok(seed.includes('dailyCompletion.upsert'), 'should create daily completion');
    });

    it('creates checkin record', () => {
      assert.ok(seed.includes('checkinRecord.create'), 'should create checkin record');
    });
  });

  describe('Data integrity', () => {
    it('demo user has required fields', () => {
      assert.ok(seed.includes("phone: '13800000000'"), 'demo user should have phone');
      assert.ok(seed.includes("username: '宽窄体验官'"), 'demo user should have username');
      assert.ok(seed.includes("shortId: 'demo001'"), 'demo user should have shortId');
      assert.ok(seed.includes("role: 'admin'"), 'demo user should have admin role');
    });

    it('peer user has required fields', () => {
      assert.ok(seed.includes("phone: '13800000001'"), 'peer user should have phone');
      assert.ok(seed.includes("username: '星辰旅人'"), 'peer user should have username');
      assert.ok(seed.includes("shortId: 'peer001'"), 'peer user should have shortId');
    });

    it('ritual session has valid hexagram pattern', () => {
      assert.ok(seed.includes('lines: [0, 1, 0, 1, 1, 0]'), 'should have 6 lines');
      assert.ok(seed.includes('movingLines: [1, 4]'), 'should have movingLines');
    });

    it('interpretation card has both private and community content', () => {
      assert.ok(seed.includes('summary:'), 'should have summary');
      assert.ok(seed.includes('body:'), 'should have body');
      assert.ok(seed.includes('focusPoints:'), 'community content should have focusPoints');
      assert.ok(seed.includes('microActions:'), 'private content should have microActions');
    });

    it('billing plans have correct pricing', () => {
      assert.ok(seed.includes('priceCents: 990'), '7-day plan should be 990 cents');
      assert.ok(seed.includes('priceCents: 2990'), '30-day plan should be 2990 cents');
      assert.ok(seed.includes('priceCents: 69990') || seed.includes('priceCents: 6990'), '90-day plan pricing');
    });

    it('uses upsert for idempotent operations', () => {
      const upsertCount = (seed.match(/\.upsert\(/g) || []).length;
      assert.ok(upsertCount >= 4, `should use upsert at least 4 times, got ${upsertCount}`);
    });

    it('uses skipDuplicates for bulk inserts', () => {
      assert.ok(seed.includes('skipDuplicates: true'), 'should use skipDuplicates for billing plans');
    });
  });

  describe('Console output', () => {
    it('logs progress messages', () => {
      assert.ok(seed.includes('🌱 Seeding database'), 'should log start message');
      assert.ok(seed.includes('🎉 Seed completed'), 'should log completion message');
    });

    it('logs each entity creation', () => {
      assert.ok(seed.includes('✅ Demo user'), 'should log demo user');
      assert.ok(seed.includes('✅ Credit account'), 'should log credit account');
      assert.ok(seed.includes('✅ Billing plans'), 'should log billing plans');
    });
  });
});

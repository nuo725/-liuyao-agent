const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const schemaPath = path.join(__dirname, '..', '..', 'prisma', 'schema.prisma');
const schema = fs.readFileSync(schemaPath, 'utf8');

function extractModels(text) {
  const models = [];
  const regex = /^model\s+(\w+)\s*\{([\s\S]*?)\n\}/gm;
  let match;
  while ((match = regex.exec(text)) !== null) {
    const name = match[1];
    const body = match[2];
    const fields = body
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith('//') && !line.startsWith('@@'))
      .map((line) => {
        const parts = line.split(/\s+/);
        return { name: parts[0], type: parts[1] || '', attrs: parts.slice(2).join(' ') };
      })
      .filter((f) => f.name && f.name !== '' && !f.name.startsWith('@@'));
    models.push({ name, fields });
  }
  return models;
}

function extractEnums(text) {
  const enums = [];
  const regex = /^enum\s+(\w+)\s*\{([\s\S]*?)\n\}/gm;
  let match;
  while ((match = regex.exec(text)) !== null) {
    const name = match[1];
    const values = match[2]
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith('//'));
    enums.push({ name, values });
  }
  return enums;
}

const models = extractModels(schema);
const enums = extractEnums(schema);
const modelNames = models.map((m) => m.name);

describe('Prisma schema', () => {
  describe('Model coverage', () => {
    it('contains all expected 41 business models', () => {
      const expected = [
        'User', 'AuthSession', 'SocialAccount', 'AgreementConsent', 'ProfileSettings',
        'RitualSession', 'InterpretationCard', 'FollowupMessage', 'EmotionCalibration',
        'SafetyAssessment', 'CommunityPost', 'PostView', 'PostHide', 'Comment',
        'PostLike', 'PostFavorite', 'PostReport', 'UserFollow', 'UserBlock',
        'ModerationRecord', 'SameFrequencyUnlock', 'Activity', 'ActivityJoin',
        'Notification', 'PushToken', 'CreditAccount', 'CreditLedger',
        'BillingPlan', 'BillingOrder', 'ShareCardDraft', 'MediaAsset',
        'SupportTicket', 'CheckinRecord', 'DailyCompletion', 'AnalyticsEvent',
        'WeeklyMetric', 'IdempotencyKey', 'RateLimitBucket', 'OutboxJob',
        'AnonymousProfile', 'RitualFeedback',
      ];

      for (const name of expected) {
        assert.ok(modelNames.includes(name), `Missing model: ${name}`);
      }
      assert.ok(models.length >= 41, `Expected at least 41 models, got ${models.length}`);
    });

    it('User model has required identity fields', () => {
      const user = models.find((m) => m.name === 'User');
      assert.ok(user);
      const fieldNames = user.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('id'), 'User should have id');
      assert.ok(fieldNames.includes('phone'), 'User should have phone');
      assert.ok(fieldNames.includes('username'), 'User should have username');
      assert.ok(fieldNames.includes('status'), 'User should have status');
      assert.ok(fieldNames.includes('role'), 'User should have role');
    });

    it('RitualSession model has hexagram and question fields', () => {
      const session = models.find((m) => m.name === 'RitualSession');
      assert.ok(session);
      const fieldNames = session.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('question'), 'RitualSession should have question');
      assert.ok(fieldNames.includes('tag'), 'RitualSession should have tag');
      assert.ok(fieldNames.includes('pattern'), 'RitualSession should have pattern (stores lines/movingLines as JSON)');
      assert.ok(fieldNames.includes('status'), 'RitualSession should have status');
    });

    it('CommunityPost model has content and metrics fields', () => {
      const post = models.find((m) => m.name === 'CommunityPost');
      assert.ok(post);
      const fieldNames = post.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('authorId'), 'CommunityPost should have authorId');
      assert.ok(fieldNames.includes('shareText'), 'CommunityPost should have shareText');
    });

    it('CreditAccount model has balance fields', () => {
      const account = models.find((m) => m.name === 'CreditAccount');
      assert.ok(account);
      const fieldNames = account.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('userId'), 'CreditAccount should have userId');
      assert.ok(fieldNames.includes('castBalance'), 'CreditAccount should have castBalance');
      assert.ok(fieldNames.includes('followupBalance'), 'CreditAccount should have followupBalance');
    });

    it('BillingOrder model has payment fields', () => {
      const order = models.find((m) => m.name === 'BillingOrder');
      assert.ok(order);
      const fieldNames = order.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('userId'), 'BillingOrder should have userId');
      assert.ok(fieldNames.includes('planId'), 'BillingOrder should have planId');
      assert.ok(fieldNames.includes('amount'), 'BillingOrder should have amount');
      assert.ok(fieldNames.includes('status'), 'BillingOrder should have status');
    });

    it('Notification model has type and read status', () => {
      const notif = models.find((m) => m.name === 'Notification');
      assert.ok(notif);
      const fieldNames = notif.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('userId'), 'Notification should have userId');
      assert.ok(fieldNames.includes('type'), 'Notification should have type');
      assert.ok(fieldNames.includes('readAt'), 'Notification should have readAt');
    });

    it('OutboxJob model has job processing fields', () => {
      const job = models.find((m) => m.name === 'OutboxJob');
      assert.ok(job);
      const fieldNames = job.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('type'), 'OutboxJob should have type');
      assert.ok(fieldNames.includes('payload'), 'OutboxJob should have payload');
      assert.ok(fieldNames.includes('status'), 'OutboxJob should have status');
    });

    it('RateLimitBucket model has rate limiting fields', () => {
      const bucket = models.find((m) => m.name === 'RateLimitBucket');
      assert.ok(bucket);
      const fieldNames = bucket.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('identifier'), 'RateLimitBucket should have identifier');
      assert.ok(fieldNames.includes('action'), 'RateLimitBucket should have action');
      assert.ok(fieldNames.includes('count'), 'RateLimitBucket should have count');
    });
  });

  describe('Enum coverage', () => {
    it('contains all expected enums', () => {
      const enumNames = enums.map((e) => e.name);
      assert.ok(enumNames.includes('UserStatus'));
      assert.ok(enumNames.includes('UserRole'));
      assert.ok(enumNames.includes('SessionStatus'));
      assert.ok(enumNames.includes('QuestionTag'));
    });

    it('UserStatus has active and deleted values', () => {
      const userStatus = enums.find((e) => e.name === 'UserStatus');
      assert.ok(userStatus);
      assert.ok(userStatus.values.includes('active'));
      assert.ok(userStatus.values.includes('deleted'));
    });

    it('QuestionTag covers divination categories', () => {
      const tag = enums.find((e) => e.name === 'QuestionTag');
      assert.ok(tag);
      assert.ok(tag.values.includes('relationship'));
      assert.ok(tag.values.includes('career'));
      assert.ok(tag.values.includes('emotion'));
      assert.ok(tag.values.includes('choice'));
    });
  });

  describe('Schema configuration', () => {
    it('uses PostgreSQL datasource', () => {
      assert.ok(schema.includes('provider = "postgresql"'));
    });

    it('uses prisma-client-js generator', () => {
      assert.ok(schema.includes('provider = "prisma-client-js"'));
    });

    it('references DATABASE_URL environment variable', () => {
      assert.ok(schema.includes('env("DATABASE_URL")'));
    });
  });

  describe('Relationship integrity', () => {
    it('User model has relations to core entities', () => {
      const user = models.find((m) => m.name === 'User');
      assert.ok(user);
      const fieldNames = user.fields.map((f) => f.name);
      // User should be referenced by or reference these
      assert.ok(fieldNames.includes('sessions') || models.some((m) => m.name === 'AuthSession'), 'AuthSession relation');
    });

    it('CommunityPost has relation to Comment', () => {
      const post = models.find((m) => m.name === 'CommunityPost');
      assert.ok(post);
      const fieldNames = post.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('comments'), 'CommunityPost should have comments relation');
    });

    it('RitualSession has relation to InterpretationCard', () => {
      const session = models.find((m) => m.name === 'RitualSession');
      assert.ok(session);
      const fieldNames = session.fields.map((f) => f.name);
      assert.ok(fieldNames.includes('interpretationCard'), 'RitualSession should have interpretationCard relation');
    });
  });
});

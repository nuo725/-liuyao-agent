const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

// Set up test environment
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_SECRET = 'test_jwt_secret_for_prisma_client_32_chars';
process.env.JWT_ACCESS_TTL = '7200';
process.env.JWT_REFRESH_TTL = '2592000';

const { getPrisma, disconnectPrisma } = require('../../src/db/prisma');

describe('Prisma client module', () => {
  describe('getPrisma()', () => {
    it('returns a PrismaClient instance', () => {
      const client = getPrisma();
      assert.ok(client, 'should return client');
      assert.ok(typeof client.$connect === 'function', 'should have $connect');
      assert.ok(typeof client.$disconnect === 'function', 'should have $disconnect');
    });

    it('returns same instance on multiple calls', () => {
      const client1 = getPrisma();
      const client2 = getPrisma();
      assert.equal(client1, client2, 'should return cached instance');
    });

    it('has user model', () => {
      const client = getPrisma();
      assert.ok(client.user, 'should have user model');
      assert.ok(typeof client.user.findUnique === 'function', 'should have findUnique');
      assert.ok(typeof client.user.create === 'function', 'should have create');
      assert.ok(typeof client.user.update === 'function', 'should have update');
      assert.ok(typeof client.user.delete === 'function', 'should have delete');
    });

    it('has communityPost model', () => {
      const client = getPrisma();
      assert.ok(client.communityPost, 'should have communityPost model');
    });

    it('has ritualSession model', () => {
      const client = getPrisma();
      assert.ok(client.ritualSession, 'should have ritualSession model');
    });

    it('has notification model', () => {
      const client = getPrisma();
      assert.ok(client.notification, 'should have notification model');
    });

    it('has creditAccount model', () => {
      const client = getPrisma();
      assert.ok(client.creditAccount, 'should have creditAccount model');
    });

    it('has billingOrder model', () => {
      const client = getPrisma();
      assert.ok(client.billingOrder, 'should have billingOrder model');
    });
  });

  describe('disconnectPrisma()', () => {
    it('is a function', () => {
      assert.equal(typeof disconnectPrisma, 'function');
    });
  });
});

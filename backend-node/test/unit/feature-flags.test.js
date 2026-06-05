const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { isEnabled, setFlag, getAllFlags, initFlags, requireFeature } = require('../../src/shared/feature-flags');

describe('Feature flags (OPS-005)', () => {
  beforeEach(() => {
    // Reset flags to defaults before each test
    delete process.env.FEATURE_COMMUNITY_PUBLISH_ENABLED;
    delete process.env.FEATURE_COMMUNITY_COMMENT_ENABLED;
    delete process.env.FEATURE_MATCH_ENABLED;
    delete process.env.FEATURE_ACTIVITY_JOIN_ENABLED;
    delete process.env.FEATURE_BILLING_ENABLED;
    delete process.env.FEATURE_RITUAL_ENABLED;
    delete process.env.FEATURE_NOTIFICATION_PUSH_ENABLED;
    delete process.env.FEATURE_SOCIAL_LOGIN_ENABLED;
    delete process.env.FEATURE_MEDIA_UPLOAD_ENABLED;
    delete process.env.FEATURE_SHARE_CARD_ENABLED;
    initFlags();
  });

  describe('Default flags', () => {
    it('defines all 10 required feature flags', () => {
      const flags = getAllFlags();
      const flagNames = Object.keys(flags);
      assert.equal(flagNames.length, 10, 'should have 10 flags');
    });

    it('has community_publish_enabled flag', () => {
      assert.ok('community_publish_enabled' in getAllFlags());
    });

    it('has community_comment_enabled flag', () => {
      assert.ok('community_comment_enabled' in getAllFlags());
    });

    it('has match_enabled flag', () => {
      assert.ok('match_enabled' in getAllFlags());
    });

    it('has activity_join_enabled flag', () => {
      assert.ok('activity_join_enabled' in getAllFlags());
    });

    it('has billing_enabled flag', () => {
      assert.ok('billing_enabled' in getAllFlags());
    });

    it('has ritual_enabled flag', () => {
      assert.ok('ritual_enabled' in getAllFlags());
    });

    it('has notification_push_enabled flag', () => {
      assert.ok('notification_push_enabled' in getAllFlags());
    });

    it('has social_login_enabled flag', () => {
      assert.ok('social_login_enabled' in getAllFlags());
    });

    it('has media_upload_enabled flag', () => {
      assert.ok('media_upload_enabled' in getAllFlags());
    });

    it('has share_card_enabled flag', () => {
      assert.ok('share_card_enabled' in getAllFlags());
    });
  });

  describe('Default values', () => {
    it('most flags default to true', () => {
      assert.equal(isEnabled('community_publish_enabled'), true);
      assert.equal(isEnabled('community_comment_enabled'), true);
      assert.equal(isEnabled('match_enabled'), true);
      assert.equal(isEnabled('activity_join_enabled'), true);
      assert.equal(isEnabled('billing_enabled'), true);
      assert.equal(isEnabled('ritual_enabled'), true);
      assert.equal(isEnabled('notification_push_enabled'), true);
      assert.equal(isEnabled('media_upload_enabled'), true);
      assert.equal(isEnabled('share_card_enabled'), true);
    });

    it('social_login_enabled defaults to false', () => {
      assert.equal(isEnabled('social_login_enabled'), false);
    });

    it('unknown flag returns false', () => {
      assert.equal(isEnabled('nonexistent_flag'), false);
    });
  });

  describe('Flag descriptions', () => {
    it('all flags have descriptions', () => {
      const flags = getAllFlags();
      for (const [name, config] of Object.entries(flags)) {
        assert.ok(config.description, `${name} should have description`);
        assert.ok(config.description.length > 0, `${name} description should not be empty`);
      }
    });

    it('descriptions are in Chinese', () => {
      const flags = getAllFlags();
      for (const [name, config] of Object.entries(flags)) {
        // Check for Chinese characters
        assert.ok(
          /[一-鿿]/.test(config.description),
          `${name} description should contain Chinese characters`
        );
      }
    });
  });

  describe('Runtime toggle', () => {
    it('setFlag changes flag value', () => {
      assert.equal(isEnabled('community_publish_enabled'), true);
      setFlag('community_publish_enabled', false);
      assert.equal(isEnabled('community_publish_enabled'), false);
    });

    it('setFlag can re-enable a flag', () => {
      setFlag('community_publish_enabled', false);
      assert.equal(isEnabled('community_publish_enabled'), false);
      setFlag('community_publish_enabled', true);
      assert.equal(isEnabled('community_publish_enabled'), true);
    });

    it('setFlag rejects unknown flags', () => {
      assert.throws(
        () => setFlag('nonexistent_flag', true),
        /Unknown feature flag/
      );
    });

    it('setFlag coerces to boolean', () => {
      setFlag('community_publish_enabled', 0);
      assert.equal(isEnabled('community_publish_enabled'), false);
      setFlag('community_publish_enabled', 1);
      assert.equal(isEnabled('community_publish_enabled'), true);
    });
  });

  describe('Environment variable override', () => {
    it('reads FEATURE_ prefixed env vars', () => {
      process.env.FEATURE_COMMUNITY_PUBLISH_ENABLED = 'false';
      initFlags();
      assert.equal(isEnabled('community_publish_enabled'), false);
    });

    it('env var "true" enables flag', () => {
      process.env.FEATURE_SOCIAL_LOGIN_ENABLED = 'true';
      initFlags();
      assert.equal(isEnabled('social_login_enabled'), true);
    });

    it('env var "1" enables flag', () => {
      process.env.FEATURE_SOCIAL_LOGIN_ENABLED = '1';
      initFlags();
      assert.equal(isEnabled('social_login_enabled'), true);
    });

    it('env var "false" disables flag', () => {
      process.env.FEATURE_BILLING_ENABLED = 'false';
      initFlags();
      assert.equal(isEnabled('billing_enabled'), false);
    });

    it('env var "0" disables flag', () => {
      process.env.FEATURE_BILLING_ENABLED = '0';
      initFlags();
      assert.equal(isEnabled('billing_enabled'), false);
    });
  });

  describe('getAllFlags', () => {
    it('returns all flags with enabled and description', () => {
      const flags = getAllFlags();
      for (const [name, config] of Object.entries(flags)) {
        assert.ok('enabled' in config, `${name} should have enabled field`);
        assert.ok('description' in config, `${name} should have description field`);
        assert.equal(typeof config.enabled, 'boolean', `${name}.enabled should be boolean`);
      }
    });

    it('returns current state after toggle', () => {
      setFlag('billing_enabled', false);
      const flags = getAllFlags();
      assert.equal(flags.billing_enabled.enabled, false);
    });
  });

  describe('requireFeature middleware', () => {
    it('calls next() when feature is enabled', () => {
      const calls = [];
      const middleware = requireFeature('community_publish_enabled');
      middleware({}, {}, () => calls.push('next'));
      assert.equal(calls.length, 1);
      assert.equal(calls[0], 'next');
    });

    it('throws when feature is disabled', () => {
      setFlag('community_publish_enabled', false);
      const middleware = requireFeature('community_publish_enabled');
      assert.throws(
        () => middleware({}, {}, () => {}),
        /功能暂未开放/
      );
    });

    it('error message includes feature description', () => {
      setFlag('billing_enabled', false);
      const middleware = requireFeature('billing_enabled');
      try {
        middleware({}, {}, () => {});
        assert.fail('should have thrown');
      } catch (err) {
        assert.ok(err.message.includes('会员'), 'error should include feature description');
      }
    });
  });
});

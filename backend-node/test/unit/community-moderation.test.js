const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { assessPostPayload, assessText } = require('../../src/modules/community/moderation');

describe('Community moderation rules', () => {
  it('approves ordinary reflection text', () => {
    const result = assessPostPayload({
      shareText: 'I paused for a moment and found a clearer next step.',
      card: {
        communitySafeContent: {
          summary: 'A quiet transition point',
          body: 'The public version keeps the reflection general.',
        },
        riskLevel: 'low',
      },
    });

    assert.equal(result.decision, 'approve');
    assert.equal(result.riskLevel, 'low');
  });

  it('limits content with private contact information', () => {
    const result = assessText('You can call me at 13800000000 later.');

    assert.equal(result.decision, 'limit');
    assert.equal(result.riskLevel, 'medium');
    assert.ok(result.categories.includes('privacy_phone'));
  });

  it('removes high-risk content before public feed', () => {
    const result = assessText('This is spam about loan and rebate offers.');

    assert.equal(result.decision, 'remove');
    assert.equal(result.riskLevel, 'high');
    assert.ok(result.categories.includes('spam'));
  });
});

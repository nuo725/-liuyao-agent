const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  AgentAdapterError,
  buildInterpretationRequest,
  createLiuyaoAgentClient,
  normalizeInterpretationResponse,
} = require('../../src/adapters/liuyao-agent');

describe('Liuyao Agent adapter', () => {
  it('is disabled until both base URL and service token are configured', () => {
    const client = createLiuyaoAgentClient({ baseUrl: '', token: '' });

    assert.equal(client.isConfigured(), false);
    assert.throws(
      () => client.assertConfigured(),
      /Liuyao Agent service is not configured/
    );
  });

  it('builds an interpretation request without leaking raw profile or auth data', () => {
    const request = buildInterpretationRequest({
      agentRequestId: 'agreq_1',
      session: {
        id: 'ritual_1',
        userId: 'user_1',
        question: '我应该换工作吗？',
        tag: 'career',
        pattern: { lines: [1, 0, 1, 0, 1, 0], movingLines: [2] },
      },
      idempotencyKey: 'idem_1',
      safety: { riskLevel: 'low', categories: [] },
    });

    assert.equal(request.agentRequestId, 'agreq_1');
    assert.equal(request.sessionId, 'ritual_1');
    assert.equal(request.mode, 'initial');
    assert.equal(request.user.userIdHash.length, 64);
    assert.equal(request.question.text, '我应该换工作吗？');
    assert.deepEqual(request.pattern.lines, [1, 0, 1, 0, 1, 0]);
    assert.equal('userId' in request.user, false);
    assert.equal('token' in request, false);
  });

  it('normalizes a valid Agent response into InterpretationCard content fields', () => {
    const normalized = normalizeInterpretationResponse({
      status: 'complete',
      privateContent: {
        summary: 'private summary',
        body: 'private body',
        followupDirections: ['direction'],
      },
      communitySafeContent: {
        title: 'safe title',
        summary: 'safe summary',
        tags: ['career'],
      },
      safety: {
        riskLevel: 'low',
        categories: [],
        decision: 'allow',
      },
    });

    assert.deepEqual(normalized.privateContent, {
      summary: 'private summary',
      body: 'private body',
      followupDirections: ['direction'],
    });
    assert.deepEqual(normalized.communitySafeContent, {
      title: 'safe title',
      summary: 'safe summary',
      tags: ['career'],
    });
    assert.equal(normalized.riskLevel, 'low');
  });

  it('rejects Agent responses that cannot be safely persisted', () => {
    assert.throws(
      () => normalizeInterpretationResponse({ status: 'complete', privateContent: {} }),
      AgentAdapterError
    );
  });
});

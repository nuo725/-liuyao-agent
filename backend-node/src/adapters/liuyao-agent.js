const crypto = require('crypto');
const { clearTimeout, setTimeout } = require('timers');

class AgentAdapterError extends Error {
  constructor(message, details = {}) {
    super(message);
    this.name = 'AgentAdapterError';
    this.details = details;
  }
}

function createLiuyaoAgentClient(options = {}) {
  const baseUrl = normalizeBaseUrl(options.baseUrl || process.env.LIUYAO_AGENT_URL || '');
  const token = options.token || process.env.LIUYAO_AGENT_TOKEN || '';
  const fetchFn = options.fetchFn || global.fetch;
  const AbortControllerCtor = options.AbortController || globalThis.AbortController;
  const timeoutMs = options.timeoutMs || Number(process.env.AGENT_TOTAL_TIMEOUT_MS || 90_000);

  function isConfigured() {
    return Boolean(baseUrl && token);
  }

  function assertConfigured() {
    if (!isConfigured()) {
      throw new AgentAdapterError('Liuyao Agent service is not configured');
    }
    if (typeof fetchFn !== 'function') {
      throw new AgentAdapterError('Fetch implementation is not available for Liuyao Agent calls');
    }
    if (typeof AbortControllerCtor !== 'function') {
      throw new AgentAdapterError('AbortController is not available for Liuyao Agent calls');
    }
  }

  async function requestInterpretation(payload) {
    assertConfigured();
    const controller = new AbortControllerCtor();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    if (typeof timer.unref === 'function') {
      timer.unref();
    }

    try {
      const response = await fetchFn(`${baseUrl}/api/v1/interpretations`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${token}`,
          'content-type': 'application/json',
          'x-agent-request-id': payload.agentRequestId,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new AgentAdapterError('Liuyao Agent returned a non-success response', {
          status: response.status,
        });
      }
      const body = await response.json();
      return normalizeInterpretationResponse(body);
    } catch (err) {
      if (err instanceof AgentAdapterError) throw err;
      throw new AgentAdapterError('Liuyao Agent request failed', { cause: err.message });
    } finally {
      clearTimeout(timer);
    }
  }

  return {
    assertConfigured,
    isConfigured,
    requestInterpretation,
  };
}

function buildInterpretationRequest(options) {
  const session = options.session;
  if (!session?.id || !session?.userId || !session?.question || !session?.pattern) {
    throw new AgentAdapterError('Cannot build Agent request from incomplete ritual session');
  }

  return {
    agentRequestId: options.agentRequestId,
    sessionId: session.id,
    mode: options.mode || 'initial',
    idempotencyKey: options.idempotencyKey || null,
    user: {
      userIdHash: hashUserId(session.userId),
      locale: options.locale || 'zh-CN',
      timezone: options.timezone || 'Asia/Shanghai',
    },
    question: {
      text: session.question,
      tag: session.tag || 'other',
    },
    pattern: {
      lines: session.pattern.lines || [],
      movingLines: session.pattern.movingLines || [],
    },
    context: options.context || {
      previousSummary: null,
      followupHistory: [],
    },
    safety: options.safety || {
      riskLevel: session.riskLevel || 'low',
      categories: [],
    },
  };
}

function normalizeInterpretationResponse(response) {
  if (!response || typeof response !== 'object') {
    throw new AgentAdapterError('Agent response must be an object');
  }
  if (!['complete', 'clarify', 'safety_degraded'].includes(response.status)) {
    throw new AgentAdapterError('Agent response status is not persistable', { status: response.status });
  }

  const privateContent = response.privateContent;
  const communitySafeContent = response.communitySafeContent;
  if (!hasText(privateContent?.summary) || !hasText(privateContent?.body)) {
    throw new AgentAdapterError('Agent response is missing private interpretation content');
  }
  if (!hasText(communitySafeContent?.summary)) {
    throw new AgentAdapterError('Agent response is missing community-safe content');
  }

  return {
    privateContent,
    communitySafeContent,
    riskLevel: response.safety?.riskLevel || 'low',
    safety: response.safety || {
      riskLevel: 'low',
      categories: [],
      decision: 'allow',
    },
  };
}

function normalizeBaseUrl(value) {
  const trimmed = String(value || '').trim();
  if (!trimmed) return '';
  if (!/^https?:\/\//.test(trimmed)) {
    throw new AgentAdapterError('Liuyao Agent base URL must start with http:// or https://');
  }
  return trimmed.replace(/\/+$/, '');
}

function hashUserId(userId) {
  return crypto.createHash('sha256').update(String(userId)).digest('hex');
}

function hasText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

module.exports = {
  AgentAdapterError,
  buildInterpretationRequest,
  createLiuyaoAgentClient,
  normalizeInterpretationResponse,
};

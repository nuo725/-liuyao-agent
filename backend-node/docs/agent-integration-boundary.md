# Agent Integration Boundary and Handoff Plan

Date: 2026-06-05

## Decision

This backend owns the authoritative business state for `问一问`: user identity, credits, ritual sessions, pattern data, interpretation-card storage, follow-up history, community-safe publishing, notifications, audit records, and operational metrics.

The independent Liuyao Agent backend owns interpretation generation, follow-up generation, structured Liuyao analysis, emotional-support wording, model routing, prompt management, and high-risk output generation.

For this backend delivery round, Agent generation and content SSE are not implemented as production code. The backend keeps stable data containers and a future orchestration boundary so the Agent service can be connected in a separate integration task.

## Source Alignment

The PRD describes the production flow where the client calls the business backend first, then the business backend calls the Agent with service credentials and streams/persists the result.

The backend TDL explicitly excludes interpretation generation, follow-up generation, model calls, prompt management, content SSE generation, and independent Agent production readiness from this business-backend delivery plan.

The resolved boundary is:

- Current acceptance: the business backend provides durable ritual data, credit/idempotency control, read permissions, safe community-card storage, and placeholders for future streaming routes.
- Future integration: the business backend will orchestrate Agent calls after the independent Agent service publishes a reviewed contract and staging endpoint.
- The Flutter client must not hold Agent credentials in production.

## Current Backend-Owned Surfaces

| Area | Current backend responsibility |
|---|---|
| Session creation | `POST /api/v1/ritual/perform` validates input, consumes credits idempotently, and creates authoritative session data. |
| Session restore | `GET /api/v1/ritual/session/:sessionId` and related read endpoints enforce ownership and restore persisted data. |
| Interpretation card storage | `InterpretationCard.privateContent` and `communitySafeContent` separate private and public-safe content. |
| Follow-up history | `FollowupMessage` stores user and assistant message history once generated content is available. |
| Community publishing | Community APIs validate card ownership and only expose the public-safe card version. |
| Notifications and async work | `OutboxJob` supports later async completion notifications without adding an external queue. |
| Safety audit | `SafetyAssessment` records risk decisions and supports later moderation/security reporting. |

## Future Service Contract

### Authentication

- Business backend calls the Agent with service-to-service credentials, such as a bearer token or signed HMAC header.
- Client tokens and user refresh tokens are never forwarded to the Agent.
- Every Agent request includes the current request ID and an `agentRequestId` for traceability.
- Agent credentials are configured only through deployment secrets, not committed files.

### Request Shape

The future Agent request should be JSON and include only the data required for the current interpretation:

```json
{
  "agentRequestId": "agreq_xxx",
  "sessionId": "ritual_session_id",
  "mode": "initial | followup | public_summary",
  "idempotencyKey": "client_or_backend_key",
  "user": {
    "userIdHash": "non_reversible_hash",
    "locale": "zh-CN",
    "timezone": "Asia/Shanghai"
  },
  "question": {
    "text": "user question",
    "tag": "relationship"
  },
  "pattern": {
    "lines": [0, 1, 0, 1, 0, 1],
    "movingLines": [1, 4]
  },
  "context": {
    "previousSummary": "short prior interpretation summary",
    "followupHistory": []
  },
  "safety": {
    "inputRiskLevel": "low",
    "categories": []
  }
}
```

The backend must not send unrelated profile details, community private content, contact data, or raw secrets.

### Response Shape

The Agent response must map cleanly into `InterpretationCard` and follow-up history:

```json
{
  "status": "complete | clarify | safety_degraded | failed",
  "sequence": 42,
  "privateContent": {
    "summary": "short summary",
    "body": "full interpretation",
    "focusPoints": [],
    "afterglow": "gentle closing",
    "followupDirections": []
  },
  "communitySafeContent": {
    "title": "safe title",
    "summary": "redacted public summary",
    "tags": []
  },
  "safety": {
    "riskLevel": "low",
    "categories": [],
    "decision": "allow"
  },
  "usage": {
    "startedAt": "2026-06-05T00:00:00.000Z",
    "completedAt": "2026-06-05T00:00:10.000Z"
  }
}
```

## SSE Boundary

- Flutter connects only to the business backend.
- The business backend may relay Agent streaming output, but it must normalize event names and never expose raw Agent credentials or internal prompt state.
- Expected client-facing events: `start`, `delta`, `checkpoint`, `complete`, `error`.
- Events must carry a monotonically increasing `sequence` so reconnect or retry behavior can avoid duplicated text.
- `Last-Event-ID` or an equivalent resume token should resume from the latest checkpoint when possible.
- The backend persists only checkpoints and final structured output; it does not persist every raw token.
- If the Agent only supports non-streaming responses, the backend may keep the same endpoint shape and emit `start` followed by one `complete` event.

## Timeout, Retry, and Idempotency

- Session creation and credit consumption remain idempotent in the business backend.
- Agent timeout must not trigger a second credit deduction.
- A retry may reuse the same `sessionId` and `idempotencyKey`.
- The backend can retry only when the Agent has not accepted the request, or when the Agent contract guarantees idempotent replay by `agentRequestId`.
- Suggested first production defaults:
  - connect timeout: 3 seconds
  - first event timeout: 15 seconds
  - total initial interpretation timeout: 90 seconds
  - follow-up timeout: 60 seconds
- When a call times out after session creation, the backend should keep the session recoverable and return a retryable error or enqueue a future async completion job.

## Degradation Rules

- Production must not fabricate a local interpretation when the Agent is unavailable.
- Agent unavailable: keep the session state recoverable, do not double-charge, and return a retryable backend response.
- Agent high-risk result: persist `SafetyAssessment`, block unsafe public-card publishing, and return the safe/degraded content shape agreed in the Agent contract.
- Agent schema mismatch: reject persistence, record an operational error, and keep the session eligible for retry.
- If async completion is introduced, completion notification should use the existing notification/outbox pipeline.

## Result Cache and Persistence

- Final initial interpretations are stored in `InterpretationCard`.
- Follow-up turns are stored in `FollowupMessage`.
- Community share data uses `communitySafeContent`, never `privateContent`.
- Cache keys must be scoped to `sessionId`, `mode`, and content version; generated content is not shared across users.
- Once a final result is persisted, read endpoints return stored backend data rather than recalling the Agent.

## Operational Requirements

Future implementation should add deployment-only configuration for:

- `AGENT_BASE_URL`
- `AGENT_SERVICE_TOKEN` or signing secret
- `AGENT_CONNECT_TIMEOUT_MS`
- `AGENT_FIRST_EVENT_TIMEOUT_MS`
- `AGENT_TOTAL_TIMEOUT_MS`
- `AGENT_MAX_RETRIES`

Metrics should include Agent request count, first event latency, total latency, timeout rate, schema mismatch rate, retry count, and degradation rate. Logs must include request IDs but must not store complete private questions or generated private content.

## Integration Plan

1. Agent team publishes OpenAPI or JSON Schema for initial interpretation, follow-up, public summary, and SSE events.
2. Backend team adds contract fixtures that validate request/response mapping against `InterpretationCard`, `FollowupMessage`, and `SafetyAssessment`.
3. Backend team implements an Agent adapter behind a feature flag, with service authentication and timeout/retry policy.
4. Staging runs full flow: create session, call Agent, stream/complete result, persist card, continue follow-up, publish public-safe card, emit notification if async.
5. Acceptance evidence is added to `PROGRESS.md`: staging endpoint, contract fixtures, timeout/retry test result, SSE reconnect check, and public-card privacy check.

## Non-Goals for Current Backend Delivery

- No model calls.
- No prompt templates.
- No local interpretation generator.
- No production content SSE implementation.
- No client-side Agent credential handling.
- No direct Flutter-to-Agent production path.

## Acceptance Evidence for AGENT-001

- This document records the PRD/TDL boundary decision.
- It defines service authentication, request/response shape, timeout/retry/idempotency rules, degradation behavior, result persistence, SSE relay boundaries, and future integration steps.
- It allows backend delivery to continue without falsely claiming Agent generation is complete.

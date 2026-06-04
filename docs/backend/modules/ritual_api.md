# Ritual API Contract (UI Simulation)

Last updated: 2026-04-22 (tag identity shell)

## Scope

Question input -> casting/suspension -> interpretation -> follow-up chat -> history revisit.

Entry note (UI):
- All ritual entry paths must pass through **Question input** first (no auto-cast on first launch).
- Entry bottom sheet focuses on greeting + today summary + CTAs; the actual question is collected on `QuestionInputScreen`.
- The ritual entry page now exposes three concrete entrance cards: manual throw, Bluetooth hardware, and local one-tap animation.
- The entry sheet keeps the mode selector lightweight; the route page owns the actual transition into each flow.
- `ResponseScreen` provides the interpretation, share-card, and tag-recap actions; `RitualChatScreen` keeps a fixed composer for follow-up continuity.
## Principles (Backend must follow)

- **No prediction / no rating**: response text must be neutral, reflective, and non-prescriptive.
- **Streaming by default**: interpretation and follow-up answers support SSE to create slow 鈥渢ypewriter鈥?pacing.
- **Deterministic state**: session state is authoritative on backend; client can resume safely after relaunch.

## Auth & Security

- **Guest**:
  - may perform ritual (`/ritual/perform`) in UI demo mode (optional), but **cannot** follow up unless authed.
- **Auth required**:
  - full-read after preview gate
  - follow-up continue
  - chat-history / chat SSE
- Headers:
  - `Authorization: Bearer <token>`
  - `Idempotency-Key: <uuid>` for `POST /ritual/perform` and message sends

## Data Models (JSON)

### `Pattern`

```json
{ "lines": [1,0,1,1,0,1], "movingLines": [2,5] }
```

### `InterpretationCardPayload`

```json
{
  "summary": "string",
  "body": "string|null",
  "followupDirections": ["string"],
  "needsClarification": false,
  "rawResponse": "string|null",
  "microActions": "string|null"
}
```

### `FollowupMessage`

```json
{
  "id": "msg_1",
  "type": "question|answer",
  "content": "string",
  "createdAt": "2026-04-16T08:35:00Z"
}
```

## UI Simulation Behavior

- This iteration is UI-only and deterministic.
- Simulation modes: `success`, `delayed`, `timeout`, `error`, `retryRecovery`.
- Follow-up supports loading/error/retry UX states.
- Local fallback keeps navigation continuity when backend is unavailable.

## Backend Anchors

- `ritual_api#start`: start agent chat (legacy name used in code TODOs)
- `ritual_api#perform`: create ritual result from question + lines.
- `ritual_api#continue`: continue follow-up conversation in session.
- `ritual_api#session`: restore session after reconnect/relaunch.
- `ritual_api#preview-gate`: first-ritual preview gating before full interpretation.
- `ritual_api#full-read`: load full interpretation after login without recomputing pattern.
- `ritual_api#followup-auth`: enforce auth before sending follow-up messages.
- `ritual_api#completion-track`: track daily ritual completion status; client uses `RitualState.lastCompletedAt` locally, backend should persist per-user daily completion for cross-device sync.
- `ritual_api#continue-chat`: restore post-ritual continued conversation session; client renders `RitualChatScreen` with collapsible summary + message history.
- `ritual_api#sse-interpretation`: stream interpretation text as SSE
- `ritual_api#sse-followup`: stream follow-up answer as SSE
- `ritual_api#tag-profile`: return the current tag identity snapshot for profile surfaces
- `ritual_api#tag-timeline`: return the chronological tag timeline for profile/history views
- `ritual_api#tag-explanation`: return the human-readable explanation for the active tag
- `share_api#entry-response`: response page share-card entry (route-level guard / template check if needed)

## Endpoints (Reserved)

### `ritual_api#start`

- Alias of `ritual_api#perform` for backward compatibility with existing code TODOs.
- Backend may implement as:
  - `POST /ritual/perform` only, or
  - keep `POST /ritual/start` and proxy to perform.

### `ritual_api#perform`
- `POST /ritual/perform`
- Request:
```json
{
  "question": "Should I switch jobs this quarter?",
  "tag": "career",
  "lines": [1,0,1,1,0,1],
  "movingLines": [2,5]
}
```
- Response:
```json
{
  "success": true,
  "data": {
    "sessionId": "sess_123",
    "pattern": {"lines": [1,0,1,1,0,1], "movingLines": [2,5]},
    "card": {
      "summary": "...",
      "body": "...",
      "followupDirections": ["...", "...", "..."]
    }
  }
}
```

### `ritual_api#continue`
- `POST /ritual/session/{sessionId}/continue`
- Request:
```json
{
  "message": "What should I do first this week?"
}
```
- Response:
```json
{
  "success": true,
  "data": {
    "id": "msg_456",
    "type": "answer",
    "content": "...",
    "suggestedDirections": ["...", "...", "..."]
  }
}
```

### `ritual_api#session`
- `GET /ritual/session/{sessionId}`

### `ritual_api#preview-gate`
- `GET /ritual/session/{sessionId}/preview`
- Purpose:
  - returns first-ritual short preview payload
  - marks client state as `preview_only`

### `ritual_api#full-read`
- `GET /ritual/session/{sessionId}/full-read`
- Purpose:
  - unlock full interpretation after auth
  - returns complete card content + followup directions

### `ritual_api#followup-auth`
- `POST /ritual/session/{sessionId}/continue`
- Required:
  - valid authenticated session token
  - reject anonymous follow-up with dedicated auth error code
  - enforce quota consume before accepting message continuation

## Suggested Error Codes

- `40001` invalid request payload
- `40401` session not found
- `40101` auth required for full-read/follow-up
- `40901` follow-up quota exhausted
- `50401` upstream timeout
- `50000` internal server error

## Endpoints (Reserved 鈥?New)

### `ritual_api#completion-track`
- `GET /ritual/user/{userId}/completion-today`
- Response: `{ "completed": true, "lastCompletedAt": "2026-04-16T08:30:00Z" }`

### `ritual_api#continue-chat`
- `GET /ritual/session/{sessionId}/chat-history`
- Response: list of previous messages for continued conversation
- `POST /ritual/session/{sessionId}/chat`
- Request: `{ "message": "..." }`
- Response: streamed AI reply via SSE (see SSE contract below)

### `ritual_api#tag-profile`

- `GET /ritual/session/{sessionId}/tag-profile`
- Purpose: expose the current tag identity snapshot for profile and recap surfaces.

### `ritual_api#tag-timeline`

- `GET /ritual/session/{sessionId}/tag-timeline?page=1&pageSize=20`
- Purpose: return the user's historical tag timeline entries.

### `ritual_api#tag-explanation`

- `GET /ritual/session/{sessionId}/tag-explanation`
- Purpose: return the current tag explanation in a stable, human-readable form.

## SSE Streaming Contract (Required)

### `ritual_api#sse-interpretation`

- `GET /ritual/session/{sessionId}/interpretation/stream`
- Response headers:
  - `Content-Type: text/event-stream`
  - `Cache-Control: no-cache`
- Event types:
  - `event: chunk` 鈥?incremental text chunk
  - `event: done` 鈥?stream finished
  - `event: error` 鈥?terminal error
- Example stream:

```text
event: chunk
data: {"delta":"浣犳鍒荤殑鍥版儜鍍忎竴鍙ｆ湭璇村嚭鐨勬皵..."}

event: chunk
data: {"delta":"鍏堟妸娉ㄦ剰鍔涗粠缁撴灉绉诲洖鍒拌韩浣撶殑鎰熷彈銆?}

event: done
data: {"sessionId":"sess_123"}
```

### `ritual_api#sse-followup`

- `GET /ritual/session/{sessionId}/followup/stream?messageId=msg_1`
- Same event format as above.

## Error Codes

- `40001` invalid request payload
- `40101` auth required for full-read/follow-up/chat
- `40401` session not found
- `40901` quota exhausted / invalid transition
- `42901` rate limited
- `50401` upstream timeout
- `50000` internal server error

## Replacement Notes

- Replace local simulation in `ritual_state.dart` and `one_tap_ceremony_page.dart`.
- Replace `RitualState.lastCompletedAt` local tracking with server-side daily completion check.
- Replace `RitualChatScreen` local message list with server-persisted chat history.
- Ensure first-ritual path always enters preview gate before full read route.
- Keep TODO anchors stable for backend rollout.

## Frontend Integration Points

- Key files:
  - `frontend/lib/state/ritual_state.dart` (session, completion track)
  - `frontend/lib/ui/screens/ritual/response_screen.dart` (typewriter streaming UX)
  - `frontend/lib/ui/screens/ritual/ritual_chat_screen.dart` (continue-chat)
- TODO anchors to search:
  - `TODO(Backend Integration)[ritual_api#perform]`
  - `TODO(Backend Integration)[ritual_api#continue]`
  - `TODO(Backend Integration)[ritual_api#continue-chat]`
- Frontend shells:
  - `frontend/lib/ui/screens/ritual/response_screen.dart` includes the tag identity recap CTA.
  - `frontend/lib/ui/screens/tag_identity/tag_identity_screen.dart` provides the shared ritual tag explanation and timeline preview UI.

## Frontend Shell Notes

- The question input page should stay minimal and should not surface an unnecessary category chip row.
- Hexagram input is designed as three visible UI modes: manual throw, Bluetooth hardware, and local one-tap animation.
- Those three modes are frontend entry choices only; no extra backend endpoint is required for the mode switch itself.
- First-visit greeting copy is driven by local first-launch / first-ritual state, not by a server-side welcome profile.
- Quota text is stage-aware UI copy: the first question stage should not surface follow-up exhaustion copy, and follow-up exhaustion belongs on the continue-chat surface.
- Casting should be quiet and restrained, with no background music in the ritual stage.
- The follow-up chat composer should remain fixed and predictable when the keyboard appears.

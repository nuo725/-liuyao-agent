# Zhouyi Backend Scaffold

This is a local backend scaffold for the Flutter frontend. It follows the handoff contracts in `docs/backend/` and keeps implementation separate from frontend code.

## Scope

- Base URL: `http://127.0.0.1:3000/api/v1`
- Android emulator URL: `http://10.0.2.2:3000/api/v1`
- No third-party Python packages required.
- Local SQLite persistence in `backend/data/dev_store.sqlite3`.
- Local Liuyao knowledge retrieval from `../六爻/`.
- Structured Liuyao reading summary for original hexagram, changed hexagram, moving lines, trigrams, and tag focus.
- Optional SiliconFlow/Qwen LLM generation when configured by environment variables.

## Implemented First

- `GET /liuyao/app/health`
- `X-Request-Id` tracing header echo on JSON, SSE, and generated share-card responses
- `GET /liuyao/app/llm/status`
- `POST /liuyao/app/chat/start`
- `POST /liuyao/app/chat/continue`
- `GET /liuyao/app/chat/session/{sessionId}`
- `POST /ritual/perform`
- ritual session, preview, full-read, tag profile, tag timeline, tag explanation, chat history, and SSE shells
- ritual completion-today lookup and `/ritual/session/{id}/chat` follow-up alias
- ritual full-read and chat-history enforce auth in strict mode
- ritual tag profile and tag timeline return `40401` for missing sessions
- ritual SSE streams include `delta`, `done`, and terminal `error` events; chat/follow-up streams enforce auth in strict mode
- auth phone/social/test-login/session/refresh/logout/recovery shells
- auth agreement version, privacy version, consent persistence, account info, password change, and phone bind-change
- auth social provider/auth-code validation and password recovery code validation
- auth phone verification code requests apply a local daily rate limit and return `42901`
- billing account, consume, checkin, reward, purchase, subscribe shells
- billing plan list, idempotent order creation, order confirmation, and order detail lookup
- billing payment callback uses local HMAC signature verification before changing order state
- billing refund callbacks reconcile local VIP entitlement when no paid order remains
- feed recommend/mine/publish/action shells
- activities list/detail/join, idempotent submission, tag-filtered leaderboard, and tag distribution
- activity join is idempotent by `(userId, activityId)` and returns viewer-specific join status
- activity detail, join, and join-status return `40401` for missing activities
- activity leaderboard includes `likeKing` and `downvoteKing` using local metrics
- activity leaderboard and tag distribution auto-link tagged posts when explicit campaign submit is omitted
- community tag feed and tag subscribe shells
- community idempotent publish, retry-safe report, follow/unfollow, block/unblock, hide, structured report reasons, classified search, tag subscribe, and viewer state
- community publish validates required `cardId` before creating a feed post
- community comments support `Idempotency-Key` to avoid duplicate insertion on retries
- community search supports `type`, page response fields, and 404 for missing post detail
- community comments and post actions return `40401` for missing posts
- community feed validates `tab=recommended|deep` and write endpoints return `42901` when local daily limits are exceeded
- community author profile returns viewer follow/block state, post metrics, recent posts, and `40401` for unknown authors
- feed mine returns only the current user's own published posts
- profile get/update/settings/check-in/tag identity/timeline shells
- profile birthday format validation and explicit account-delete confirmation
- profile birthday must be a real non-future `YYYY-MM-DD` date
- profile interactions and browse history are generated from the current user's server-side actions
- profile account deletion can be cancelled during the local cooling-off window
- notifications list/read/dismiss/token sync shells
- notifications filtering, detail, unread count, token registration, and state sync
- notifications UI polish capability flags for message-center controls and empty states
- notifications read/dismiss/delete return `40401` for missing messages
- share render/save/publish/external shells
- server-rendered SVG share cards via `/share/card/render`
- share draft save and community publish support `Idempotency-Key`; external share returns a structured payload
- share community publish validates required `cardId` before creating a feed post
- share community publish returns `40401` when the referenced card cannot be found
- match unlock/radar/same-frequency shells with device-day idempotency
- match same-frequency data returns `40301` until the device is unlocked
- match same-frequency validates `tab=users|history` and returns `40001` for invalid tabs
- support feedback, FAQ, and ticket status lookup
- support feedback applies a local daily rate limit and returns `42901`
- support feedback validates `client.platform=android|ios` when client metadata is provided
- media upload validates auth, image mime type, size limits, JSON metadata, and basic multipart/form-data requests
- knowledge health/search endpoints
- structured Liuyao reading metadata in chat and ritual responses

## Response Rules

The backend follows the product handoff requirements:

- no deterministic prediction
- no scoring or good/bad judgment
- no lucky/unlucky framing
- no medical, legal, financial, or other professional replacement advice
- tag identity remains a readable reflection layer, not a verdict
- structured Liuyao readings are context summaries, not outcome predictions

## Auth Mode

Login endpoints issue short-lived local bearer tokens plus refresh tokens and persist them in SQLite.

Default mode is frontend-friendly: if a request has no bearer token, the backend falls back to `user_demo`.

Strict mode can be enabled for backend contract testing:

```powershell
$env:ZHOUYI_STRICT_AUTH="true"
python backend/server.py
```

Then protected endpoints return:

```json
{ "success": false, "error": { "code": "40101", "message": "Authentication required" } }
```

Use the login response token as:

```text
Authorization: Bearer <accessToken>
```

Session payloads include `accessToken`, `refreshToken`, `expiresAt`, and `refreshExpiresAt`. Refresh a session with:

```text
POST /api/v1/auth/refresh
{ "refreshToken": "<refreshToken>" }
```

Refresh tokens are one-time use in this local scaffold. Refreshing rotates both tokens; logout revokes the active access token and its paired refresh token. Invalid or expired refresh attempts return `40102`.

## Credit Policy

The local backend follows `docs/backend/modules/credit_api.md`:

- normal users reset to at least `1` cast and `1` follow-up per day
- VIP users reset to at least `2` casts and `4` follow-ups per day
- `/liuyao/app/chat/start` and `/ritual/perform` consume one `cast`
- `/liuyao/app/chat/continue` and ritual continue routes consume one `followup`
- insufficient balance returns `40901`
- `Idempotency-Key` is recorded for credit consumption to avoid duplicate deduction on retries

Compatible endpoints:

- `GET /credit/account`
- `POST /credit/consume`
- `POST /credit/reset`
- existing `/billing/...` endpoints remain available for frontend compatibility
- `/credit/consume` validates `type=cast|followup`, requires `amount=1`, and keeps retry-safe idempotency

## Validation

Write endpoints return `40001` for invalid payloads. Current checks include:

- ritual `question` is required and capped at 300 characters
- ritual `lines` must contain exactly six `0|1` values
- `movingLines` must contain values from `1` to `6`
- follow-up `message` is required and capped at 800 characters
- community comment text is required
- profile username/gender/bio are constrained
- support feedback category must be `bug|suggestion|abuse|other`

Validation happens before credit consumption, so invalid ritual/follow-up requests do not deduct quota.

## Run

Use any Python 3.10+ interpreter:

```powershell
python backend/server.py
```

If the system Python is not on PATH, run it with an explicit interpreter path.

Runtime state is written to:

```text
backend/data/dev_store.sqlite3
```

Delete that file to reset the local backend to seeded demo data.

## Test

Run backend contract tests:

```powershell
python -m unittest discover -s backend/tests
```

The tests start a temporary strict-auth backend on a local port, use an isolated SQLite data directory, and clean it up after the run.

## Optional LLM

By default, the backend uses local Liuyao knowledge retrieval and deterministic neutral text. To enable SiliconFlow/Qwen:

```powershell
$env:LIUYAO_LLM_ENABLED="true"
$env:SILICONFLOW_API_KEY="your_api_key"
$env:LIUYAO_LLM_MODEL="Qwen/Qwen3-32B"
python backend/server.py
```

Optional:

```powershell
$env:SILICONFLOW_BASE_URL="https://api.siliconflow.cn/v1"
$env:LIUYAO_LLM_TIMEOUT="60"
```

Check status:

```text
GET /api/v1/liuyao/app/llm/status
```

If the remote model is disabled, missing a key, times out, or returns an invalid payload, the backend falls back to local knowledge retrieval.

Remote LLM responses are expected to be strict JSON:

```json
{ "answer": "string", "followups": ["string"], "safetyNotes": ["string"] }
```

Invalid remote output is repaired up to two times with a JSON-only repair prompt. If repair still fails, the backend uses the local Liuyao knowledge fallback.

## Share Card Rendering

`POST /api/v1/share/card/render` and `POST /api/v1/share/card/render-with-theme` generate local SVG share cards under the runtime data directory and return:

```json
{
  "imageUrl": "http://127.0.0.1:3000/api/v1/static/share/card_x.svg",
  "mime": "image/svg+xml",
  "width": 1080,
  "height": 1440
}
```

Generated files are development artifacts and live under `backend/data/share_cards/` unless `ZHOUYI_DATA_DIR` is set.

## Key Contract Groups

- Liuyao agent: `/liuyao/app/...`
- Ritual and tag identity: `/ritual/...`
- Auth: `/auth/...`
- Billing and credits: `/billing/...`
- Community/feed: `/community/...` and `/feed/...`
- Profile: `/profile/me/...`
- Notifications: `/notifications/...`
- Activity campaigns: `/activity/...` and `/activities/...`
- Share cards: `/share/...`
- Match/same-frequency: `/match/...`
- Support: `/support/feedback`
- Liuyao knowledge retrieval: `/knowledge/...`

## Frontend Configuration

For Android emulator builds, the frontend default already points Liuyao agent calls to:

```text
http://10.0.2.2:3000/api/v1
```

For business API modules, pass:

```text
--dart-define=BUSINESS_API_BASE_URL=http://10.0.2.2:3000/api/v1
```

For web/local desktop tests, use `127.0.0.1` or `localhost` instead.

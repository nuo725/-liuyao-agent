# Match API Contract (UI Simulation)

Last updated: 2026-04-17

## Scope

`此刻` page galaxy plaza and same-frequency discovery, including:
- persistent galaxy orbit background (content-neutral, no feed)
- shake-to-unlock state
- same-frequency hub page (`同频用户` + `历史同频`)
- top-right same-frequency hub entry (shown after unlock)

## Auth & Security

- Unlock + same-frequency data can be guest or authed depending on product; recommended:
  - `POST /match/unlock` guest allowed (device-level unlock)
  - `GET /match/same-frequency` auth optional (guest sees limited pool)
- Headers:
  - `Authorization: Bearer <token>` (optional)
  - `X-Device-Id: <string>` (recommended for guest unlock binding)

## Data Models (JSON)

### `SameFrequencyUser`

```json
{
  "id": "u_1",
  "name": "若闻",
  "role": "心理咨询师",
  "signature": "101101",
  "avatarUrl": "https://cdn/.../128.jpg|null",
  "bio": "string|null",
  "matchedReason": "string|null"
}
```

### `SameFrequencyStory`

```json
{
  "id": "h_1",
  "name": "王阳明",
  "role": "龙场悟道",
  "quote": "string",
  "imageUrl": "https://cdn/.../1200.jpg|null"
}
```

## UI Simulation Behavior

- Default page is **galaxy plaza**; user sees orbit background + shake prompt.
- Shake unlock triggers a center guide card with three actions:
  - open same-frequency users
  - open same-frequency history
  - close (animated collapse toward top-right entry icon)
- After unlock, galaxy plaza can directly open same-frequency content and top-right hub icon appears.
- `活动` remains in bottom navigation only (no duplicated top-right entry in `此刻`).
- Data remains local/mock and signature-matching based.

## Backend Anchors

- `match_api#unlock-entry`
- `match_api#samefreq-page`
- `match_api#radar-plaza`

## Endpoints (Reserved)

### `match_api#unlock-entry`
- `POST /match/unlock`
- Request:
```json
{
  "deviceId": "dev_123",
  "trigger": "shake"
}
```
- Response:
```json
{
  "success": true,
  "data": {
    "unlocked": true,
    "unlockToken": "unlock_abc"
  }
}
```

### `match_api#samefreq-page`
- `GET /match/same-frequency?tab=users|history&page=1&pageSize=20`
- Response:

```json
{
  "success": true,
  "data": {
    "tab": "users",
    "signature": "101101",
    "items": [],
    "hasMore": false,
    "nextPage": 2
  }
}
```

### `match_api#radar-plaza`

- Purpose:
  - backend does **not** drive scan animation
  - backend returns unlock state + (optional) lightweight “today signature” to display
- `GET /match/radar/status`
- Response:

```json
{
  "success": true,
  "data": {
    "unlocked": true,
    "signature": "101101",
    "unlockedAt": "2026-04-16T08:30:00Z|null"
  }
}
```

## Suggested Error Codes

- `40001` invalid request payload
- `40101` auth required
- `40301` unlock required
- `40401` match data not found
- `42901` rate limited
- `50000` internal server error

## Idempotency

- `POST /match/unlock` should be idempotent by `(deviceId, day)`:
  - multiple shakes within a day return the same `unlockToken`

## Frontend Integration Points

- Code TODO anchors:
  - `TODO(Backend Integration)[match_api#unlock-entry]` in `frontend/lib/ui/screens/match_screen.dart`
  - `TODO(Backend Integration)[match_api#samefreq-page]` in `frontend/lib/ui/screens/match_screen.dart`

## Replacement Notes

- Replace local `same_frequency_unlocked_v1` persistence with server unlock state.
- Replace local signature matching pool with backend recommendations.
- Radar scan visuals are client-side only; backend only needs to provide unlock state + same-frequency data.
- Keep dedicated same-frequency hub route unchanged.


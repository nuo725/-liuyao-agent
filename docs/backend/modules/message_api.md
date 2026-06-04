# Message API Contract (UI Simulation)

Last updated: 2026-04-16 (framework)

## Scope

Message center filters, unread badge sync, mark-read, delete, detail open, pull-to-refresh simulation, and local persistence.
Community interactions and activity join-status updates are also simulated as message sources.

Entry note (UI):
- Bottom navigation no longer has a dedicated `消息` tab.
- Message center is reachable from `宽窄之间` top-right **通知弹层** via `消息中心` entry.

## Auth & Security

- Auth required for all endpoints: `Authorization: Bearer <token>`
- Idempotency recommended for write endpoints: `Idempotency-Key: <uuid>`

## Data Models (JSON)

### `NotificationMessage`

```json
{
  "id": "notif_001",
  "type": "system|interaction|activity|browse",
  "title": "string",
  "body": "string|null",
  "data": { "targetId": "string|null", "targetType": "feed|card|activity|null" },
  "createdAt": "2026-04-16T08:30:00Z",
  "read": false
}
```

### `NotificationListResponse`

```json
{
  "items": [],
  "hasMore": false,
  "nextPage": 1,
  "unreadCount": 3
}
```

## UI Simulation Behavior

- All operations run locally with deterministic simulated failures.
- Unread count recalculates immediately after operations.
- Read/deleted state persists across relaunch.
- Edge states covered:
  - empty by filter
  - empty after deletion
  - operation failure fallback

## Backend Anchors

- `message_api#list`
- `message_api#mark-read`
- `message_api#mark-all-read`
- `message_api#dismiss`
- `message_api#unread-count`
- `message_api#sync-state`
- `message_api#ui-polish`
- `message_api#register-token`
- `message_api#unregister-token`
- `message_api#hybrid`

## Endpoints (Reserved)

### `message_api#list`
- `GET /notifications?page=0&pageSize=20`
- Response:

```json
{ "success": true, "data": { "items": [], "hasMore": false, "nextPage": 1, "unreadCount": 0 } }
```

### `message_api#unread-count`
- `GET /notifications/unread-count`

### `message_api#mark-read`
- `POST /notifications/{id}/read`
- Notes: idempotent (double-read returns ok).

### `message_api#mark-all-read`
- `POST /notifications/read-all`

### `message_api#dismiss`
- `POST /notifications/{id}/dismiss`

### `message_api#register-token`

- `POST /notifications/token`
- Request:

```json
{ "token": "string", "platform": "android|ios|web" }
```

### `message_api#unregister-token`

- `DELETE /notifications/token`

### `message_api#hybrid`

- Purpose: API + local cache hybrid strategy for poor network environments.

### `message_api#sync-state`
- `PUT /notifications/state`
- Request:
```json
{
  "readIds": ["n1", "n2"],
  "dismissedIds": ["n3"]
}
```

### `message_api#ui-polish`
- Purpose:
  - preserve message header/chips/card interaction visual parity
  - provide style flags for clickable states (`mark all read`, swipe actions)

## Suggested Error Codes

- `40001` invalid request payload
- `40101` authentication required
- `40401` message not found
- `40901` invalid state transition
- `50000` internal server error

## Replacement Notes

- Replace local persistence in `message_screen.dart` with server-state sync.
- Preserve current filter and badge behavior.

## Pagination

- Page-number: `page`, `pageSize`, `hasMore`, `nextPage`

## Frontend Integration Points

- `frontend/lib/ui/screens/message_screen.dart`
- `frontend/lib/services/notification_service.dart`


# Support API Contract (UI Simulation)

Last updated: 2026-04-16 (framework)

## Scope

Help & feedback entry from Settings page: submit feedback, view FAQ, and track ticket status.

## Backend Anchors

- `support_api#feedback`

## Endpoints (Reserved)

### `support_api#feedback`

- `POST /support/feedback`
- Auth required: `Authorization: Bearer <token>`
- Request:

```json
{
  "category": "bug|suggestion|abuse|other",
  "content": "string",
  "contact": "string|null",
  "client": { "platform": "android|ios", "version": "1.0.0" }
}
```

- Response:

```json
{ "success": true, "data": { "ticketId": "t_1" } }
```

## Error Codes

- `40001` invalid payload
- `40101` auth required
- `42901` rate limited
- `50000` internal error

## Frontend Integration Points

- `frontend/lib/ui/screens/profile_screen.dart` settings row "帮助与反馈"



# API Contract Template (Backend Handoff)

Last updated: YYYY-MM-DD

## Scope

- What this module covers and does not cover.

## Principles

- **UI simulation first**: frontend may run local mocks; backend should match contracts.
- **Idempotency by default**: client may retry; backend must be safe.
- **No future-telling / no judgement**: keep content neutral and reflective (product boundary).

## Auth & Security

- **Auth required**: yes/no (and which endpoints).
- **Headers**:
  - `Authorization: Bearer <token>`
  - `X-Request-Id: <uuid>` (optional, recommended)
- **Rate limits** (suggested):
  - `42901` for too frequent requests.

## Data Models (JSON)

### `ModelName`

```json
{
  "id": "string",
  "createdAt": "2026-04-16T08:30:00Z"
}
```

## Endpoints

### `module_api#anchor`

- **Method/Path**: `GET /path`
- **Purpose**: 1-2 sentences
- **Request**:
  - **Query**: `page`, `pageSize` or `cursor`
  - **Body**:

```json
{}
```

- **Response**:

```json
{
  "success": true,
  "data": {}
}
```

- **Error cases**:
  - `40001` invalid payload
  - `40101` auth required
  - `40401` not found
  - `40901` invalid state transition
  - `42901` rate limited
  - `50000` internal error

## Pagination

- Choose one:
  - Page-number: `page`, `pageSize`, `hasMore`, `nextPage`
  - Cursor: `cursor`, `nextCursor`, `hasMore`

## Idempotency & State Machine

- Which operations are safe to retry (recommended: all `POST` support `Idempotency-Key`).
- State transitions table (if any).

## Frontend Integration Points

- Code TODO anchors to search:
  - `TODO(Backend Integration)[module_api#anchor]`
- Files to update when integrating backend.



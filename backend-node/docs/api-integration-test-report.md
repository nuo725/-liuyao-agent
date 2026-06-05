# API Integration Mainline Test Report

Date: 2026-06-05

## Scope

This report records the automated backend API mainline coverage for `TEST-001`.

The suite is implemented in:

```text
test/integration/api-mainline.test.js
```

The test uses the real Express `createApp()` factory, mounted route modules, request ID middleware, validation middleware, authentication middleware, idempotency middleware, feature flags, and response envelopes. Service modules are replaced with deterministic test stubs so the HTTP contract can run without a local PostgreSQL database.

## Covered API Areas

| Area | Covered path |
|---|---|
| Auth | `POST /api/v1/auth/phone/login`, `GET /api/v1/auth/session` |
| Profile | `GET /api/v1/profile/me` |
| Credits | `GET /api/v1/credits/account` |
| Billing | `GET /api/v1/billing/plans`, `POST /api/v1/billing/order/create` |
| Media | `POST /api/v1/media/upload` |
| Notifications | `GET /api/v1/notifications/unread-count` |
| Ritual | `POST /api/v1/ritual/perform` |
| Community | `GET /api/v1/community/feed`, `POST /api/v1/community/post` |
| Match | `GET /api/v1/match/radar/status` |
| Activities | `GET /api/v1/activities/list`, `POST /api/v1/activities/:id/join` |

## Assertions

- Every covered endpoint returns the standard `{ success: true, data }` envelope.
- Authenticated routes accept a valid JWT and receive the expected `userId`.
- Idempotent write routes accept `Idempotency-Key`.
- Request bodies and query parameters pass real route validation.
- Feature-gated routes pass with the repository's default enabled flags.
- The test can run in local CI without a PostgreSQL dependency.

## Boundary

This test closes the local automated API integration gap. It does not replace the remaining staging-only evidence:

- `DB-001`: real `migrate deploy`, `seed`, and restore verification in PostgreSQL.
- `FE-CONTRACT-001`: current Flutter pages running against the real backend and database.
- `ADAPTER-001`: production or staging provider SDK/callback verification.

## Validation Commands

```text
node --test test/integration/api-mainline.test.js
node --test test/**/*.test.js
```

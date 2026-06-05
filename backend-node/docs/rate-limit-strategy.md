# Sensitive Rate Limit Strategy

Date: 2026-06-05

## Decision

Production sensitive endpoint limiting uses PostgreSQL-backed fixed windows stored in:

```text
rate_limit_buckets
```

Development and unit tests may use the in-memory fallback by setting:

```text
RATE_LIMIT_STORE=memory
```

Production must set:

```text
RATE_LIMIT_STORE=database
```

The local security check blocks production settings that do not use the database store.

## Covered Endpoints

| Endpoint | Action | Current Window |
|---|---|---|
| `POST /api/v1/auth/phone/send-code` | `send-code` | 5 requests / 60 seconds |
| `POST /api/v1/auth/phone/login` | `phone-login` | 10 requests / 60 seconds |
| `POST /api/v1/auth/password/recovery` | `password-recovery` | 3 requests / 300 seconds |

Additional sensitive endpoints can reuse `rateLimit(action, max, windowSeconds)`.

## Behavior

- Authenticated requests are keyed by `user:<userId>`.
- Anonymous requests are keyed by IP address.
- Responses include `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset`.
- Exceeding a limit returns `42901`.

## Validation

- Unit tests cover window reset and limit exceed behavior for the in-memory algorithm.
- Prisma schema includes `RateLimitBucket`.
- Migration `202606050002_rate_limit_buckets` creates the production table.
- Production readiness still depends on running `npm run db:deploy` in a PostgreSQL environment.

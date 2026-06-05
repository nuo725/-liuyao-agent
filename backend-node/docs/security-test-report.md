# Security Mainline Test Report

Date: 2026-06-05

## Scope

This report records the automated backend security regression coverage for `TEST-002`.

The suite is implemented in:

```text
test/unit/security-mainline.test.js
```

## Covered Cases

| Requirement | Automated check |
|---|---|
| No token | `GET /private` rejects missing bearer token with `40101`. |
| Expired token | Expired JWT rejects with `40102`. |
| Unauthorized role access | A regular user cannot pass an admin-only role guard and receives `40301`. |
| Idempotency replay | Repeating a write request with the same `Idempotency-Key` replays the first successful response and does not rerun the handler. |
| Illegal upload | Non-image upload metadata is rejected before persistence with `40001`. |
| Private interpretation leakage | Community publishing assessment reads `communitySafeContent` and ignores `privateContent`. |
| Moderation bypass | Spam/contact-data text is removed and tagged with both policy and privacy categories. |
| High-risk card publishing | High-risk interpretation cards are limited even if surrounding share text looks safe. |

## Current Boundary

These tests are local automated regression checks. They do not replace staging penetration testing, dependency/secret scanning, or real provider callback verification.

The production-facing security acceptance that still needs external evidence is tracked separately through:

- `ADAPTER-001` for provider configuration and callback signatures.
- `FE-CONTRACT-001` for real Flutter-to-backend flow regression.
- `OPS-VERIFY-001~003` for staging backup, performance, monitoring, and alert evidence.

## Validation Command

```text
node --test test/unit/security-mainline.test.js
```

The full backend test suite should also pass through:

```text
node --test test/**/*.test.js
```

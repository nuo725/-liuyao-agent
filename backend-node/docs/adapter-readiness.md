# External Adapter Readiness

Date: 2026-06-05

## Scope

This document records the local readiness gate added for `ADAPTER-001`.

The current repository can now check whether production or staging deployment configuration has stopped relying on mock/dev fallback settings for:

- SMS verification provider.
- WeChat login.
- QQ login.
- S3-compatible object storage.
- Push notification provider.
- Payment callback signature secret.
- Liuyao Agent service endpoint and token.

## Command

```text
node scripts/adapter-check.js
```

For staging or production release checks, run in strict mode:

```text
ADAPTER_CHECK_STRICT=1 node scripts/adapter-check.js
```

The package script is:

```text
npm run ops:adapter-check
```

## Result Semantics

- In local development, missing external provider credentials are warnings.
- In strict mode or `NODE_ENV=production`, missing credentials become blocking failures.
- Passing this script means the required configuration values are present; it does not prove that each provider accepted a real request.

## Required External Evidence

`ADAPTER-001` can only move from partial to complete after staging or production-like regression records are attached:

| Adapter | Required evidence |
|---|---|
| SMS | Successful verification send to a controlled test number, provider request ID recorded. |
| WeChat / QQ | Successful OAuth callback exchange in staging, mapped to `SocialAccount`. |
| Object storage | Upload, public URL fetch, avatar/cover reference, and cleanup verification. |
| Push | FCM or APNS test push delivery result and worker job ID. |
| Payment | Signed callback accepted, invalid signature rejected, order status updated. |
| Liuyao Agent | Service-to-service auth accepted, adapter request/response fixtures pass, and timeout/failure path tested against staging. |

## Current Status

The backend now has automated configuration checks, unit tests for the adapter readiness gate, and a server-side Liuyao Agent adapter boundary in `src/adapters/liuyao-agent.js`. Real provider and live Agent regression remain external staging tasks, so `ADAPTER-001` is still marked as partial in `PROGRESS.md`.

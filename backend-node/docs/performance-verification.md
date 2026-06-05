# Performance Verification

Date: 2026-06-05

## Scope

This document records the executable performance scenario kit added for `OPS-VERIFY-002`.

The repository now supports two levels of performance checks:

- `scripts/perf-smoke.js`: single endpoint load smoke test.
- `scripts/perf-scenarios.js`: mainline scenario runner for feed, post detail, comment create, and ritual creation.

## Scenario Command

Run against a staging backend with realistic seed data:

```text
PERF_BASE_URL=https://staging-api.example.com \
PERF_AUTH_TOKEN=<staging-user-access-token> \
PERF_POST_ID=<published-post-id> \
npm run ops:perf-scenarios -- --requests=500 --concurrency=25 --maxP95Ms=800 --maxErrorRate=0.01
```

On Windows PowerShell:

```powershell
$env:PERF_BASE_URL="https://staging-api.example.com"
$env:PERF_AUTH_TOKEN="<staging-user-access-token>"
$env:PERF_POST_ID="<published-post-id>"
npm run ops:perf-scenarios -- --requests=500 --concurrency=25 --maxP95Ms=800 --maxErrorRate=0.01
```

## Covered Scenarios

| Scenario | Method | Endpoint | Required setup |
|---|---|---|---|
| `community_feed` | GET | `/api/v1/community/feed?tab=recommended&page=1&pageSize=20` | Published public feed content. |
| `post_detail` | GET | `/api/v1/community/post/:postId` | `PERF_POST_ID`. |
| `comment_create` | POST | `/api/v1/community/post/:postId/comments` | `PERF_AUTH_TOKEN`, `PERF_POST_ID`. |
| `ritual_perform` | POST | `/api/v1/ritual/perform` | `PERF_AUTH_TOKEN`, enough credits, idempotency enabled. |

## Acceptance Evidence Required

`OPS-VERIFY-002` can only move to complete after the staging run output is attached with:

- Environment name and commit SHA.
- Request count and concurrency.
- P50/P95/max latency per scenario.
- Error rate and status code distribution per scenario.
- Confirmation that write scenarios used a controlled test user and disposable seed data.
- Follow-up issue for any scenario above threshold.

## Current Status

The scenario runner and tests are in place. A real staging run is still required, so `OPS-VERIFY-002` remains partial in `PROGRESS.md`.

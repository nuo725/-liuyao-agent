# Performance Verification

Date: 2026-06-05

## Scope

This document records the executable performance scenario kit added for `OPS-VERIFY-002`.

The repository now supports two levels of performance checks:

- `scripts/perf-smoke.js`: single endpoint load smoke test.
- `scripts/perf-scenarios.js`: mainline scenario runner covering all major modules.

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

### Public / optional-auth read endpoints

| Scenario | Method | Endpoint | Required setup |
|---|---|---|---|
| `community_feed_recommended` | GET | `/api/v1/community/feed?tab=recommended&page=1&pageSize=20` | Published public feed content. |
| `community_feed_deep` | GET | `/api/v1/community/feed?tab=deep&page=1&pageSize=20` | Published deep-dive feed content. |
| `community_search` | GET | `/api/v1/community/search?q=测试&type=post&page=1&pageSize=10` | Indexed posts. |
| `post_detail` | GET | `/api/v1/community/post/:postId` | `PERF_POST_ID`. |
| `post_comments` | GET | `/api/v1/community/post/:postId/comments` | `PERF_POST_ID`. |
| `activity_list` | GET | `/api/v1/activities/list?page=1&pageSize=10` | Published activities. |
| `billing_plans` | GET | `/api/v1/billing/plans` | Active membership plans. |
| `health` | GET | `/api/v1/health` | None. |

### Authenticated read endpoints

| Scenario | Method | Endpoint | Required setup |
|---|---|---|---|
| `profile_me` | GET | `/api/v1/profile/me` | `PERF_AUTH_TOKEN`. |
| `notifications_list` | GET | `/api/v1/notifications?page=1&pageSize=20` | `PERF_AUTH_TOKEN`. |
| `notifications_unread_count` | GET | `/api/v1/notifications/unread-count` | `PERF_AUTH_TOKEN`. |
| `credits_account` | GET | `/api/v1/credits/account` | `PERF_AUTH_TOKEN`. |
| `match_same_frequency` | GET | `/api/v1/match/same-frequency` | `PERF_AUTH_TOKEN`. |

### Authenticated write endpoints

| Scenario | Method | Endpoint | Required setup |
|---|---|---|---|
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

The scenario runner and tests are in place. 16 scenarios covering all major modules (community, profile, notifications, credits, match, activities, billing, ritual, health). A real staging run is still required, so `OPS-VERIFY-002` remains partial in `PROGRESS.md`.

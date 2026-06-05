# Release Acceptance Runbook

Date: 2026-06-05

## Purpose

This runbook is the execution checklist for the remaining backend上线验收 items that cannot be completed honestly in the current local environment.

The repository already has feature implementation, local tests, dry-run scripts, and verification gates. The remaining items require a PostgreSQL/staging environment, current Flutter pages, real monitoring endpoints, or real external provider credentials.

## Prerequisites

- Clean Git worktree and recorded commit SHA.
- PostgreSQL environment that can be discarded or restored.
- Deployment environment using the same commit SHA as the test report.
- A controlled staging user with enough credits.
- A published public post ID for performance and contract checks.
- Provider credentials for SMS, WeChat, QQ, object storage, push, and payment callback testing.
- Dashboard or alert receiver that can record webhook payloads.

## DB-001: Migration, Seed, and Restore

Run:

```powershell
npm run db:deploy
npm run db:seed
```

Verify:

```powershell
npm run db:backup
npm run db:restore -- --file=<backup-file> --clean
```

Required evidence:

- Environment name.
- Commit SHA.
- `db:deploy` output.
- `db:seed` output.
- Backup file name and manifest.
- Restore command output.
- Post-restore validation query or endpoint result.

Completion rule:

`DB-001` can move to complete only after a real PostgreSQL deploy/seed/restore record is attached.

## FE-CONTRACT-001: Flutter Main Page Contract Regression

Run backend with the staging database and execute:

```powershell
$env:RUN_CONTRACT_DB="1"
npm run test:contract
```

Then run the current Flutter pages manually or through Flutter automation against the same backend:

- Auth.
- Profile.
- Ritual.
- Community.
- Notifications.
- Match.
- Activities.

Required evidence:

- Backend base URL.
- Test account.
- Contract test output.
- Flutter screen list and pass/fail result.
- Any screenshots or logs for failed screens.

Completion rule:

`FE-CONTRACT-001` can move to complete only after current Flutter pages, not only stubbed API tests, run against the real backend and database.

## OPS-VERIFY-001: Backup and Restore Drill

Run:

```powershell
npm run db:backup
npm run db:restore -- --file=<backup-file> --clean
```

Required evidence:

- Backup file and manifest.
- Restore target database.
- Restore output.
- Verification endpoint or SQL query after restore.
- Data loss or mismatch notes.

Completion rule:

This item completes only after restore is performed against a disposable PostgreSQL database and verification passes.

## OPS-VERIFY-002: Performance Report

Prepare:

```powershell
$env:PERF_BASE_URL="<staging-backend-url>"
$env:PERF_AUTH_TOKEN="<staging-user-access-token>"
$env:PERF_POST_ID="<published-post-id>"
```

Run:

```powershell
npm run ops:perf-scenarios -- --requests=500 --concurrency=25 --maxP95Ms=800 --maxErrorRate=0.01
```

Required evidence:

- Scenario output JSON.
- Request count and concurrency.
- P50/P95/max latency per scenario.
- Error rate and status code distribution per scenario.
- Follow-up issue for any threshold breach.

Completion rule:

`OPS-VERIFY-002` completes only after staging scenario output is recorded.

## OPS-VERIFY-003: Dashboard and Alert联调

Run readiness and metrics checks:

```powershell
curl <base-url>/api/v1/ready
curl <base-url>/api/v1/metrics
```

Run alert check:

```powershell
$env:MONITOR_BASE_URL="<staging-backend-url>"
$env:ALERT_WEBHOOK_URL="<webhook-url>"
npm run ops:alert-check
```

Required evidence:

- Dashboard screenshot or link.
- `/ready` output.
- `/metrics` output.
- Alert webhook payload.
- Alert receiver delivery record.

Completion rule:

This item completes only after a real webhook or dashboard alert is triggered and recorded.

## ADAPTER-001: External Provider Regression

Run strict config gate:

```powershell
$env:ADAPTER_CHECK_STRICT="1"
npm run ops:adapter-check
```

Provider checks:

| Provider | Required action |
|---|---|
| SMS | Send verification code to a controlled number and record provider request ID. |
| WeChat | Complete OAuth callback exchange and verify `SocialAccount`. |
| QQ | Complete OAuth callback exchange and verify `SocialAccount`. |
| Object storage | Upload media, fetch public URL, attach as avatar/cover, then clean up. |
| Push | Send test push and record worker job ID plus provider delivery status. |
| Payment | Accept valid signed callback and reject invalid signature. |
| Liuyao Agent | Verify service auth, timeout path, and failure path once adapter implementation is enabled. |

Completion rule:

This item completes only after provider request IDs or staging logs are attached. Passing `ops:adapter-check` alone is partial evidence.

## Traceability

Before changing release acceptance scope or completion counts, check:

```text
docs/acceptance-traceability.md
```

The traceability table maps every acceptance ID in `PROGRESS.md` to `BACKEND_TDL_AND_DELIVERY_PLAN.md` and `PRODUCT_PRD.md`.

## Reporting Template

Run local preflight before creating or filling an evidence package:

```powershell
npm run ops:acceptance-preflight
```

Use JSON output when attaching the preflight result to release automation:

```powershell
npm run ops:acceptance-preflight -- --format=json
```

Generate a Markdown evidence template:

```powershell
npm run ops:acceptance-evidence -- --item=DB-001 --environment=staging --commit=<commit-sha>
```

Generate templates for every remaining item:

```powershell
npm run ops:acceptance-evidence -- --environment=staging --commit=<commit-sha>
```

Create a file-based release evidence package:

```powershell
npm run ops:acceptance-package -- --out=release-evidence/staging-<date> --environment=staging --commit=<commit-sha>
```

The package contains:

- `acceptance-evidence.md` for human-filled evidence.
- `acceptance-manifest.json` for release tracking and audit metadata.

Validate a completed evidence Markdown file before marking an item done:

```powershell
npm run ops:acceptance-evidence:check -- --file=<evidence.md> --item=DB-001 --require-pass=1
```

Validate the full remaining-item evidence bundle:

```powershell
npm run ops:acceptance-evidence:check -- --file=<evidence.md> --require-pass=1
```

Summarize the current package status:

```powershell
npm run ops:acceptance-status -- --package=release-evidence/staging-<date>
```

Use JSON output when the status must be attached to CI or release automation:

```powershell
npm run ops:acceptance-status -- --package=release-evidence/staging-<date> --format=json
```

Use this format in `PROGRESS.md` update notes or release notes:

```text
Date:
Commit SHA:
Environment:
Item:
Commands:
Evidence files/links:
Result:
Follow-up issues:
```

## Current Local Limitation

The current local workspace does not expose Docker/PostgreSQL, and no real provider credentials are available. Local work can improve checks and automation, but these remaining items must stay partial until the required external evidence exists.

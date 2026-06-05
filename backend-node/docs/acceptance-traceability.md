# Backend Acceptance Traceability

This document maps the release acceptance matrix in `backend-node/PROGRESS.md` back to:

- `../BACKEND_TDL_AND_DELIVERY_PLAN.md`
- `../PRODUCT_PRD.md`

The acceptance matrix is not a separate product plan. It is a release-readiness layer derived from the TDL delivery plan and the PRD acceptance criteria. Local scripts, dry-runs, and mock tests may prove implementation capability, but external-environment items remain partial until the listed evidence exists.

## Traceability Matrix

| Acceptance ID | Why It Exists | BACKEND_TDL Source | PRODUCT_PRD Source | Completion Evidence |
|---------------|---------------|--------------------|--------------------|---------------------|
| CONTRACT-001 | Freeze the public API shape before Flutter switches from mock/local paths to the business backend. | Sections 3.2, 6.6, 9 final acceptance. | Sections 9, 15.1, 15.2. | `docs/api-contract-decision.md`, OpenAPI, contract regression output. |
| DB-001 | Prove PostgreSQL schema, migration, seed, backup, and rollback readiness beyond local schema files. | Sections 2.2, 3.1, 5.1 BE-003/BE-004/BE-012, 5.9 OPS-001, 6.7. | Sections 6.2, 8, 10, 15.2. | `migrate deploy`, `seed`, backup/restore, and post-restore validation records. |
| RATE-001 | Ensure sensitive operations are idempotent and rate-limited with a production-capable store. | Sections 3.1 PostgreSQL usage, 5.1 BE-013, 6.4. | Sections 11.2, 15.2. | DB-backed rate limit configuration and regression tests. |
| AGENT-001 | Keep business backend and independent Liuyao Agent responsibilities separated while defining the integration boundary. | Sections 1.1, 3 architecture, 6.6, 9 final acceptance. | Sections 6.1, 6.2, 6.3, 7, 11.1, 15.2. | `docs/agent-integration-boundary.md` and later staging integration evidence. |
| TEST-001 | Cover the backend API mainlines used by existing Flutter pages. | Sections 6.5, 6.6, 9 final acceptance. | Sections 5, 8, 15.1. | API integration test report and passing automated tests. |
| TEST-002 | Prove auth, privacy, moderation, upload, idempotency, and authorization safety before release. | Sections 6.4, 6.5, 9 final acceptance. | Sections 11.1, 11.2, 15.3. | Security regression report and passing automated tests. |
| OPS-VERIFY-001 | Prove backup and restore can be executed in a real PostgreSQL environment. | Sections 5.9 OPS-002, 6.7, 6.8, 9 final acceptance. | Sections 11.2, 15.2. | Backup file, manifest, restore output, and post-restore verification. |
| OPS-VERIFY-002 | Prove Feed, comments, and ritual-session capacity with a real performance report. | Sections 5.9 OPS-004, 6.5 performance testing, 9 final acceptance. | Sections 11.2, 12, 15.1. | Scenario output, P50/P95/max latency, error-rate report, and threshold notes. |
| OPS-VERIFY-003 | Prove readiness, metrics, dashboard, and alerting are wired in a real environment. | Sections 5.9 OPS-006, 6.4, 9 final acceptance. | Sections 11.3, 12, 15.2. | `/ready`, `/metrics`, dashboard link/screenshot, webhook delivery record. |
| FE-CONTRACT-001 | Prove current Flutter main pages work against the business backend contract. | Sections 1, 6.6, 9 final acceptance. | Sections 1, 5, 9, 15.1. | Contract test output plus Flutter page checklist in PostgreSQL/staging mode. |
| ADAPTER-001 | Prove real external providers are configured and observable, not only mocked locally. | Sections 3.1, 4 data model, 5.2 AUTH-005/PROFILE-002, 5.3 BILLING-003, 5.5 notifications, 6.4. | Sections 8.1, 8.7, 8.9, 11.1, 15.2. | SMS, social login, object storage, push, payment callback, and Agent adapter staging records. |

## Maintenance Rules

- When an acceptance ID is added to `PROGRESS.md`, add a matching row here.
- Every row must cite both source documents, even when one document is broader product/architecture context.
- If a task is backed only by local automation, keep its status partial unless real release evidence exists.
- If TDL or PRD changes, update this table before changing release completion counts.

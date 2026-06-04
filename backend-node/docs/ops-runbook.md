# Backend Ops Runbook

## Git version management

Every backend delivery round must end with:

1. `git status --short` to confirm the changed file list.
2. Verification commands such as Prisma generate, lint, tests, or contract checks.
3. A Git commit with a clear message after verification passes.
4. A clean working tree unless follow-up work is intentionally left unstaged and documented.

## Database backup

Dry-run the backup command first:

```powershell
npm run db:backup -- --dry-run
```

Create a PostgreSQL custom-format dump:

```powershell
npm run db:backup
```

Backups are written to `backend-node/backups/` and ignored by Git. Each successful backup also writes a small `.manifest.json` file with the redacted database URL and creation time.

## Restore drill

Dry-run a restore command:

```powershell
npm run db:restore -- --file=backups/zhouyi-example.dump --dry-run
```

Restore into the configured `DATABASE_URL`:

```powershell
npm run db:restore -- --file=backups/zhouyi-example.dump
```

Use `--clean` only for a disposable drill database because it asks `pg_restore` to drop existing objects before restoring:

```powershell
npm run db:restore -- --file=backups/zhouyi-example.dump --clean
```

## Security check

Run the local security gate before production-style delivery:

```powershell
npm run ops:security-check
```

The check validates PostgreSQL connection string shape, JWT secret strength, unsafe production defaults, package lock presence, and Git ignore coverage for `.env`, uploads, and backups.

## Performance smoke test

Run a light local smoke test against the health endpoint:

```powershell
npm run ops:perf-smoke -- --url=http://127.0.0.1:3000/api/v1/health --requests=100 --concurrency=10
```

The command prints total requests, failures, status code distribution, average latency, p50, p95, and threshold status. Tune thresholds per environment:

```powershell
npm run ops:perf-smoke -- --url=https://api.example.com/api/v1/health --requests=500 --concurrency=25 --maxP95Ms=800 --maxErrorRate=0.01
```

## Monitoring and alerts

The backend exposes:

- `GET /api/v1/ready` for dependency readiness.
- `GET /api/v1/metrics` for in-process request counts, status codes, error rate, and latency.

Run a local alert check:

```powershell
npm run ops:alert-check -- --baseUrl=http://127.0.0.1:3000 --dry-run
```

Production can set `MONITOR_BASE_URL`, `ALERT_WEBHOOK_URL`, `ALERT_MAX_ERROR_RATE`, and `ALERT_MAX_AVG_DURATION_MS`. When a webhook URL is configured and `--dry-run` is omitted, alert payloads are posted as JSON.

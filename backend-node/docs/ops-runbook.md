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

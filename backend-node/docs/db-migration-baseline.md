# Database Migration Baseline

Date: 2026-06-05

## Baseline

The Prisma migration baseline currently includes:

```text
prisma/migrations/202606050001_initial_schema/migration.sql
prisma/migrations/202606050002_rate_limit_buckets/migration.sql
```

It was generated from the current `prisma/schema.prisma` with:

```powershell
node node_modules/prisma/build/index.js migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma --script
```

The schema was validated with:

```powershell
node node_modules/prisma/build/index.js validate --schema prisma/schema.prisma
```

## Deployment Steps

When PostgreSQL is available:

```powershell
docker compose up -d
npm run db:deploy
npm run db:seed
```

For local development that needs an editable migration workflow:

```powershell
npm run db:migrate
npm run db:seed
```

## Rollback Strategy

Prisma Migrate does not provide an automatic down migration. Production rollback should prefer forward repair:

1. Restore from the latest verified backup if the migration corrupts data.
2. Create a new forward migration that repairs schema shape or data.
3. Use feature flags to disable high-risk writes while repair is in progress.
4. Record the incident, backup used, commands run, and verification query results.

## Acceptance Status

Migration baseline is created and schema validation passes. Real `migrate deploy`, `seed`, backup, and restore verification still require a running PostgreSQL environment.

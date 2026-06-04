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

## Feature flags & rollback

### Available feature flags

| Flag | Env Variable | Description |
|------|-------------|-------------|
| `community_publish_enabled` | `FEATURE_COMMUNITY_PUBLISH_ENABLED` | 社区发布功能 |
| `community_comment_enabled` | `FEATURE_COMMUNITY_COMMENT_ENABLED` | 社区评论功能 |
| `match_enabled` | `FEATURE_MATCH_ENABLED` | 同频匹配功能 |
| `activity_join_enabled` | `FEATURE_ACTIVITY_JOIN_ENABLED` | 活动报名功能 |
| `billing_enabled` | `FEATURE_BILLING_ENABLED` | 会员与订单功能 |
| `ritual_enabled` | `FEATURE_RITUAL_ENABLED` | 仪式会话功能 |
| `notification_push_enabled` | `FEATURE_NOTIFICATION_PUSH_ENABLED` | 推送通知功能 |
| `social_login_enabled` | `FEATURE_SOCIAL_LOGIN_ENABLED` | 社交登录 |
| `media_upload_enabled` | `FEATURE_MEDIA_UPLOAD_ENABLED` | 媒体上传功能 |
| `share_card_enabled` | `FEATURE_SHARE_CARD_ENABLED` | 分享卡功能 |

### Emergency rollback via environment variables

Set any flag to `false` via environment variable to disable a feature immediately:

```bash
# Disable community publishing (emergency)
FEATURE_COMMUNITY_PUBLISH_ENABLED=false

# Disable billing (payment issue)
FEATURE_BILLING_ENABLED=false
```

Restart the service for env changes to take effect.

### Runtime toggle via admin API

```bash
# List all flags
curl -H "Authorization: Bearer <admin-token>" http://localhost:3000/api/v1/admin/feature-flags

# Disable a flag
curl -X PUT -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}' \
  http://localhost:3000/api/v1/admin/feature-flags/community_publish_enabled
```

### Rollback principles

- 社区审核故障时关闭发布，不关闭只读 Feed。
- 支付故障时关闭新订单，不修改已有订单状态。
- 数据库迁移必须支持向前修复或回滚脚本。
- 回滚后记录原因和时间，便于事后复盘。

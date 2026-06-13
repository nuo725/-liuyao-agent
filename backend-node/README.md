# Zhouyi Node Backend

This is the main business API backend for the Flutter app.

## Prerequisites

- Node.js 24 or compatible active LTS
- Docker Desktop, recommended for PostgreSQL

## Local Setup

```powershell
copy .env.example .env
docker compose up -d postgres
npm install
npm run db:generate
npm run db:deploy
npm run db:seed
npm start
```

The server listens on:

```text
http://localhost:3000/api/v1
```

## Database

`docker-compose.yml` starts PostgreSQL on port `5432` with:

```text
database: zhouyi
user: zhouyi
password: zhouyi_dev_password
```

The matching local `DATABASE_URL` is already in `.env.example`.

## Useful Commands

```powershell
npm run dev
npm run lint
npm test
npm run db:generate
npm run db:deploy
npm run db:seed
```

## Production Notes

- Set `NODE_ENV=production`.
- Set `IDEMPOTENCY_STORE=database` so write-route `Idempotency-Key` replay data is stored in PostgreSQL.
- Keep `LIUYAO_AGENT_URL` and `LIUYAO_AGENT_TOKEN` empty until the independent Liuyao Agent service has a staging endpoint and reviewed contract.

## Health Check

```powershell
Invoke-RestMethod http://localhost:3000/api/v1/health
```

If PostgreSQL is not running, the health endpoint can respond with `db: disconnected`.

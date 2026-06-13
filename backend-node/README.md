# Zhouyi Node Backend

This is the main business API backend for the Flutter app.

## Prerequisites

- Node.js 20 LTS or newer
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

## Health Check

```powershell
Invoke-RestMethod http://localhost:3000/api/v1/health
```

If PostgreSQL is not running, the health endpoint can respond with `db: disconnected`.

# Liuyao Agent Project

This repository contains the maintained Liuyao business backend workspace:

- `backend-node/`: Node.js business backend with PostgreSQL and Prisma.
- `frontend/`: Flutter app snapshot.
- `docs/`: product, backend, and project documentation.
- `六爻/`: Liuyao knowledge base materials.

## Prerequisites

- Git
- Node.js 24 or compatible active LTS
- Docker Desktop, recommended for local PostgreSQL
- Flutter 3.44.x or compatible stable Flutter SDK, only when working on the Flutter app

## Clone

```powershell
git clone https://github.com/nuo725/-liuyao-agent.git
cd -liuyao-agent
```

## Run The Node Backend

The Node backend is the maintained business API backend.

```powershell
cd backend-node
copy .env.example .env
docker compose up -d postgres
npm install
npm run db:generate
npm run db:deploy
npm run db:seed
npm start
```

The API listens on:

```text
http://localhost:3000/api/v1
```

Health check:

```powershell
Invoke-RestMethod http://localhost:3000/api/v1/health
```

## Run The Flutter App

Open a second terminal:

```powershell
cd frontend
flutter pub get
flutter run
```

For Android emulator builds, the app defaults to:

```text
http://10.0.2.2:3000/api/v1
```

For web, Windows, macOS, or Linux local runs, the app defaults to:

```text
http://localhost:3000/api/v1
```

To override the backend URL:

```powershell
flutter run --dart-define=BUSINESS_API_BASE_URL=http://localhost:3000/api/v1
```

For Android emulator override:

```powershell
flutter run --dart-define=BUSINESS_API_BASE_URL=http://10.0.2.2:3000/api/v1
```

## Verification

Backend Node:

```powershell
cd backend-node
npm run lint
npm test
```

Flutter:

```powershell
cd frontend
flutter test
```

`flutter analyze` currently reports existing info-level lint items in older UI files. The test suite still passes.

## Production Notes

- `backend-node/` is the only maintained backend in this repository.
- Set `IDEMPOTENCY_STORE=database` outside local development so `Idempotency-Key` replays are backed by PostgreSQL.
- Configure `LIUYAO_AGENT_URL` and `LIUYAO_AGENT_TOKEN` only after the independent Liuyao Agent service is available.

## Files Not Committed

The repository intentionally excludes local secrets and build artifacts:

- `backend-node/.env`
- `node_modules/`
- Flutter build folders
- APK files
- local logs

Use `.env.example` as the template for local backend configuration.

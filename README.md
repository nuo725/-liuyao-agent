# Liuyao Agent Project

This repository contains the full Liuyao agent workspace:

- `frontend/`: Flutter app.
- `backend-node/`: Node.js business backend with PostgreSQL and Prisma.
- `backend/`: Python local Liuyao backend scaffold.
- `docs/`: product, backend, and project documentation.
- `六爻/`: Liuyao knowledge base materials.

## Prerequisites

- Git
- Flutter 3.44.x or compatible stable Flutter SDK
- Node.js 20 LTS or newer
- Python 3.10 or newer
- Docker Desktop, recommended for local PostgreSQL

## Clone

```powershell
git clone https://github.com/nuo725/-liuyao-agent.git
cd -liuyao-agent
```

## Run The Node Backend

The Node backend is the main business API backend.

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

## Optional Python Backend

The Python backend is a local scaffold that uses only the Python standard library.

```powershell
python backend/server.py
```

Its default API base is also:

```text
http://127.0.0.1:3000/api/v1
```

Do not run the Python backend and Node backend on port `3000` at the same time.

## Verification

Backend Node:

```powershell
cd backend-node
npm run lint
npm test
```

Python backend:

```powershell
python -m unittest discover -s backend/tests
```

Flutter:

```powershell
cd frontend
flutter test
```

`flutter analyze` currently reports existing info-level lint items in older UI files. The test suite still passes.

## Files Not Committed

The repository intentionally excludes local secrets and build artifacts:

- `backend-node/.env`
- `node_modules/`
- Flutter build folders
- APK files
- local logs

Use `.env.example` as the template for local backend configuration.

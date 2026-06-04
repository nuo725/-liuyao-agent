# Zhouyi App (UI Simulation First)

This repository contains a Flutter mobile app focused on UI simulation workflows.

## Current Product Scope

- Community stream: `Recommended` + `Deep Talk` tabs only.
- Ritual flow: question -> cast -> response -> follow-up -> history.
- Message center: filters, unread sync, mark-read, delete, detail, pull-to-refresh simulation.
- Profile and activity modules remain UI-first with local persistence.

## Backend Integration Status

- Runtime remains UI-only in this iteration.
- Integration points are reserved through `TODO(Backend Integration)[module_api#anchor]` markers.
- API handoff docs live in `docs/modules/`.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Versioning and Rollback

- See `docs/VERSIONING_AND_ROLLBACK.md`.
- Use module tags for rollback safety.
- Docs index: `docs/README.md`.

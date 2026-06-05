# API Contract Decision

Date: 2026-06-05

## Decision

The backend will keep the current implemented public runtime prefix and response envelope for this delivery round:

- Runtime prefix: `/api/v1`
- Success envelope: `{ "success": true, "data": ... }`
- Failure envelope: `{ "success": false, "error": { "code": "...", "message": "..." }, "requestId": "req_xxx" }`

The TDL originally proposed `/v1` and `{ code, message, data, requestId }`. That shape is now treated as a documented historical target, not the active implementation contract, because the backend implementation, OpenAPI file, tests, and local app wiring have already converged on `/api/v1` plus the `success/data` envelope.

## Compatibility Strategy

Before a production release, choose one of these two paths:

1. Keep `/api/v1` as the canonical public API and update the TDL wording to match the implemented contract.
2. Add an explicit compatibility layer that mounts `/v1` and transforms responses to `{ code, message, data, requestId }`.

This repository currently chooses option 1 for backend acceptance, because it avoids silently changing response shapes that Flutter screens and tests may already depend on.

## Required Follow-up

- OpenAPI remains the source of truth for the implemented backend.
- Flutter contract tests must assert `/api/v1` and the `success/data` envelope.
- Any future `/v1` compatibility layer must be added as a separate task with tests for both path prefixes and both envelopes.

## Acceptance Evidence

- `openapi/openapi.yaml` uses `/api/v1` servers.
- Existing HTTP tests assert `success=true`.
- This document records the explicit deviation from the original TDL target and removes ambiguity for future validation.

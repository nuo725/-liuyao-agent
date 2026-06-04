# Frontend Handoff Guide

Last updated: 2026-04-24

## What to hand to backend

This handoff package is meant to let backend engineers continue implementation without first rebuilding frontend context.

Read in this order:

1. `docs/README.md`
2. `docs/frontend/PRODUCT_UI_SUMMARY.md`
3. `docs/project/PRD_v0.7.0_tag_identity_growth.md`
4. `docs/backend/modules/README.md`
5. The module contracts for the relevant feature area

## What the frontend already defines

- Ritual has three visible hexagram entry modes:
  - manual throw
  - Bluetooth hardware
  - local one-tap animation
- First-visit ritual copy is a local frontend rule.
- Quota copy is stage-aware UI copy:
  - first question stage only shows interpretation balance
  - follow-up exhaustion is shown on the continue-chat surface
- Tag identity is a readable frontend surface shared by ritual, profile, community, and activity UI.

## What to ignore in the handoff zip

- `backend/`
- `build/`
- `.dart_tool/`
- `.git/`
- APKs and other build outputs
- local logs and cache files

## Backend-facing contracts to start from

- `auth_api.md`
- `credit_api.md`
- `community_api.md`
- `ritual_api.md`
- `profile_api.md`
- `activity_api.md`
- `message_api.md`
- `billing_api.md`
- `share_api.md`


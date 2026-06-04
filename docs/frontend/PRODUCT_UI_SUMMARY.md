# Product UI Summary

Last updated: 2026-04-22

## Product Position

This project is a Flutter app that simulates the product experience first and defers real backend integration to documented contract anchors.

The app is not a prediction tool, a game, or a scoring system. Its product intent is a restrained emotional mirror with a clear ritual flow and lightweight social surfaces.

## Current Runtime Mode

- UI simulation first
- Local persistence and mock services remain the default
- Backend integration points are reserved through `TODO(Backend Integration)[module_api#anchor]`

## Current UI Scope

- Auth:
  - login gate with agreement consent simulation
  - password recovery entry and compact UI-only recovery screen
  - account-delete consent gate and explicit confirm action
- Community:
  - `Recommended` and `Deep Talk` tabs only
  - full-bleed feed presentation
  - post detail, comment thread, follow, like, favorite, report, search, and pagination simulation
  - tag feed entry and subscribe shell
  - publish composer with image entry promoted above the fold
- Ritual:
  - minimal question input
  - a visible ritual entry page that routes into three concrete input entrances: manual throw, Bluetooth hardware, local one-tap animation
  - casting and suspension with quieter animation treatment
  - interpretation presentation
  - follow-up chat with pinned composer and stage-aware quota copy
  - history revisit
  - daily completion and continue-chat flow
  - first-visit greeting copy that shows a short welcome instead of carrying over historical context
  - tag identity entry and readable recap shell
- Share:
  - visual share card canvas
  - theme/background editing
  - save, share, and publish simulation
- Message center:
  - unread badge sync
  - filter, mark read, delete, detail open, refresh simulation
- Profile:
  - edit profile
  - share profile
  - check-in calendar
  - account-delete flow with agreement gate, readable agreement pages, and explicit confirmation
  - tag identity card and timeline preview
- Activity and match:
  - campaign detail and leaderboard simulation
  - galaxy/plaza style discovery surface
  - tag distribution display layer

## Delivery Rules

For UI surfaces that will later hand off to the backend, keep the following in sync:

1. a code update
2. a changelog entry
3. a module API doc update
4. a backend TODO anchor in code when the feature still needs server integration

Pure frontend presentation rules, such as first-visit greetings, stage-aware quota copy, and ritual input mode entry pages, should be documented in the PRD and module notes even when they do not require a new backend endpoint.

## Not In Scope

- Real backend integration at runtime
- Cross-device production consistency
- Production session guarantees


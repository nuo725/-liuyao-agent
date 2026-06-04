# Versioning and Rollback

Last updated: 2026-04-21

## Purpose

This document defines the release/tag discipline for the UI simulation project and the minimum rollback steps for a safe recovery.

## Branching Rules

- Work on feature branches.
- Merge only after local `flutter analyze`, `flutter test`, and release build verification.
- Do not rewrite published tags.

## Tag Strategy

Current milestone tags:

- `v0.6.0-feature-iteration`
- `v0.6.1-feed-instagram-flat`
- `v0.6.2-feed-media-author`
- `v0.6.3-feed-seed-migration-fix`
- `v0.6.4-production-readiness-audit`
- `v0.6.5-orbit-framework-polish`
- `v0.6.6-orbit-bugfix-round`
- `v0.6.7-cold-joke-activity-and-polish`

Older milestones remain documented in `CHANGELOG.md` and are kept as historical reference only.

## Changelog Discipline

Each release entry should record:

- what changed
- impact scope
- backend anchors added or updated
- rollback tag

## Rollback Procedure

1. Identify the last stable tag.
2. Check out that tag or create a rollback branch from it.
3. Rebuild and verify the app.
4. Communicate the rollback tag and the impact of the rollback.

## Practical Rule

- Use the newest stable tag for day-to-day recovery.
- Use `CHANGELOG.md` for the detailed narrative of each release.


---
title: Docs
description: Documentation index for Toishi Note
status: living
updated: 2026-08-09
---

# Docs

Not a task list — this is where "what we decided and why" lives, so contributors (human or AI) don't have to reverse-engineer decisions from the code. Updated alongside the change that prompted it, not backfilled later.

Docs are written in English so contributors anywhere can read them without relying on translation. (Conversation and commit discussion around this project may still happen in Japanese — that's fine, it doesn't need to leak into the docs themselves.)

Every file starts with YAML frontmatter (`title` / `description` / `status` / `updated`). That's future-proofing for a static site generator (Astro, 11ty, Decap CMS, ...) — no site exists yet, this just keeps the structure ready.

## Structure

- **`product/`** — product direction and UX/UI decisions.
  - [roadmap.md](product/roadmap.md) — what ships from the v0.1.0 public beta through v2.0, and why each feature was accepted, rescoped, or dropped
  - [ux-roadmap.md.old](product/ux-roadmap.md.old) — archived. Superseded by the above for *what ships when*, but still the record of *why* for the persona, the auth design, and several features that took more than one attempt to get right.
- **`engineering/`** — dev environment and coding rules, for contributors.
  - [dev-environment.md](engineering/dev-environment.md) — devcontainer design decisions
  - [deployment.md](engineering/deployment.md) — self-hosting via Docker Compose: required configuration, reverse-proxy pattern, redeploying
  - [backup.md](engineering/backup.md) — backing up and restoring `storage/`, tested end to end, not just documented
  - [coding-style.md](engineering/coding-style.md) — Ruby/Rails coding conventions
  - [asset-strategy.md](engineering/asset-strategy.md) — why front-end dependencies are vendored and never CDN-loaded, and where the Node toolchain stands
  - [git-workflow.md](engineering/git-workflow.md) — commit message format, branch naming, merge strategy
  - [verification.md](engineering/verification.md) — what `bin/ci` runs and why, how to read its output, OSS-specific checks beyond the day-to-day suite
  - [release-process.md](engineering/release-process.md) — the move to a fresh repository, and how releases are cut
  - [pre-beta-checklist.md](engineering/pre-beta-checklist.md) — what has to be true before that move happens

## `status` values

- `draft` — not settled yet, expect it to change
- `living` — current policy; may still evolve, but follow it for now
- `stable` — not expected to change much

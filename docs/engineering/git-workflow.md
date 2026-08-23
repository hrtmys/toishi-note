---
title: Git Workflow
description: Commit message format, branch naming, and merge strategy for this repository
status: living
updated: 2026-08-09
---

# Git workflow

## Commit messages: Conventional Commits

```
<type>(<scope>): <summary>

<body — explains *why*, not what changed line-by-line; git diff already
shows that. Wrap around 72 chars.>
```

`type` is one of:

| Type | For |
|---|---|
| `feat` | a new user-facing feature |
| `fix` | a bug fix |
| `docs` | documentation only (`docs/`, README, comments-as-documentation) |
| `refactor` | code change that isn't a feature or a fix |
| `test` | adding or fixing tests, no production code change |
| `chore` | dependency bumps, tooling, anything with no source impact |
| `ci` | changes to `.github/workflows` |
| `style` | formatting only (rare — Rubocop/Prettier should catch most of this) |
| `perf` | a performance improvement |

`scope` is optional and short (e.g. `fix(auth): ...`, `feat(todo): ...`). Skip it when the summary is already unambiguous.

Summary: imperative mood ("add", not "added"/"adds"), no trailing period, lowercase after the colon.

## Branch names

`<type>/<short-kebab-description>`, using the same `type` vocabulary as commits — e.g. `feat/passkey-login`, `fix/scrap-item-validation`, `docs/coding-style`. Keep it short enough to read in a PR list; the commit body carries the detail, not the branch name.

## Merge strategy

Feature branches merge into `main` with `--no-ff` (a real merge commit, not a fast-forward or a squash). That keeps each unit of work as a bounded, revertable set of commits in history, and the merge commit message summarizes what the branch was for. Don't commit directly to `main`.

## Where this doesn't apply yet

History before this convention was adopted doesn't follow it, and won't be rewritten to match — see [release-process.md](release-process.md) for the one point where old history does get discarded (the v1.0 reset), which is a one-time exception, not an ongoing rebase practice.

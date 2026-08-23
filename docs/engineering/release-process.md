---
title: Release Process
description: What happens at the v0.1.0 public beta, including the move to a fresh repository
status: living
updated: 2026-08-15
---

# Release process

## v0.1.0: a clean start in a new repository

At **v0.1.0, the public beta**, the project moves to a **brand-new GitHub repository, `toishi-note`**, and the current tree is pushed into it as a single fresh initial commit. The existing repository (`oyashiro_note`, itself renamed once already from `citron_web`) is left behind rather than rewritten.

**This used to say v1.0.** The move was pulled forward once the release plan grew a real beta period: the point of inviting strangers to run the app is giving them somewhere to file issues, which has to be the repository they'll still be using at v1.0. Nothing else in this document changed — the mechanics below are the same either way. What has to be true before the push is [pre-beta-checklist.md](pre-beta-checklist.md); what ships in each release afterwards is [roadmap.md](../product/roadmap.md).

Why the whole history is being dropped: early history carries prototype churn and, at one point, an accidentally-committed `vendor/bundle` tree that inflates `.git` to ~80MB even though those files aren't tracked anymore today.

**Why a new repo rather than an orphan commit + force-push into this one** (this supersedes an earlier version of this document, which planned the in-place rewrite):

- **It actually sheds the 80MB.** Rewriting history in place doesn't shrink anything by itself — the old objects stay in GitHub's copy, and keeping a `pre-v1` tag to stay recoverable deliberately keeps them reachable. A new repo leaves them behind by construction.
- **No force-push**, so no invalidated clones/forks and no one-time exception to [git-workflow.md](git-workflow.md)'s "don't rewrite history" rule to justify.
- **The rename lands for free.** The repo name becomes `toishi-note` at the same moment, instead of a separate rename step.

**Mechanics, when the time comes:**

1. Confirm `main` clears every blocker in [pre-beta-checklist.md](pre-beta-checklist.md), tests included.
2. Create `toishi-note` on GitHub, empty.
3. Push the current tree as one fresh initial commit. Check `.gitignore` covers `vendor/bundle` and `app/assets/builds` *before* the first push — the point of this exercise is not to import the same mistake into a clean repo.
4. Tag `v0.1.0` on that initial commit.
5. **Decide what happens to the old repo.** Leaving it public leaves the mis-pushed content publicly reachable, which defeats the purpose — archive it, make it private, or delete it. Deleting also frees the old name for the redirect to stop, so do it deliberately rather than by default.
6. Update the local remote (`git remote set-url origin ...`) — it still points at `citron_web.git` and has been riding GitHub's rename redirect ever since.

## Until then

Keep merging feature branches into `main` normally (see [git-workflow.md](git-workflow.md)). This is a beta-day event, not something to do preemptively — the repository stays `oyashiro_note` until then, even though the product is already named Toishi Note.

## After the move

Releases are tagged from `main` and get a `CHANGELOG.md` entry. Beta releases (v0.x) may break things between versions, but must always migrate an existing instance cleanly — someone running the beta on their own VPS is exactly who this is for, and losing their notes to a schema change is unrecoverable trust. From v1.0 on, follow semver properly.

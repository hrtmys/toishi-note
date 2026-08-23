---
title: Verification
description: What bin/ci runs, why, and how to read its output without burning a conversation on it
status: living
updated: 2026-08-16
---

# Verification

Every PR in this project goes through the same gauntlet before merging: the full test suite (unit/controller/integration and system/browser), RuboCop, Brakeman, and dependency-vulnerability scanning across both Ruby and JS. `bin/ci` runs all of it in one command and reports a compact summary — this doc is about *why* each piece is there and how to read the result, not a tutorial on the tools themselves.

## Running it

```sh
bin/ci          # everything — required before merging a PR
bin/ci quick    # skips test:system and yarn audit — fast local iteration only, not a merge gate
```

Output looks like:

```
CI (full) — 2026-08-16 01:30 UTC
✅ yarn build           built                                                   (2.1s)
✅ rails test           247 runs, 634 assertions, 0 failures, 0 errors, 0 skips (7.3s)
✅ rails test:system    104 runs, 396 assertions, 0 failures, 0 errors, 0 skips (152.4s)
✅ rubocop              136 files inspected, no offenses detected               (8.3s)
✅ brakeman             Warnings: 0                                             (6.8s)
⚠️  bundler-audit        1 advisory (GHSA-mwm8-39rw-8826) — bin/bundler-audit check for details (1.1s)
✅ yarn audit            0 vulnerabilities found                                 (0.6s)

RESULT: PASS, with advisories to review (bundler-audit)
```

✅ = passed. ⚠️ = a non-blocking advisory worth a human glance (see below) — doesn't fail the run. ❌ = blocking failure; `RESULT: FAIL` and a non-zero exit code follow, along with just the failing test names (not their backtraces) and a pointer to the full log.

Full, unfiltered output from every step is always written to `tmp/ci_logs/<UTC timestamp>/<step>.log` regardless of pass/fail — the summary is a filter on what gets *read* by default, not a reduction in what gets *captured*. Only the last 5 runs are kept.

## Why each step exists

- **rails test / rails test:system** — the actual regression suite. System tests are the only thing in this project that catches real Turbo/Stimulus behavior (frame scoping, event listener cleanup, Turbo Drive's body-replacement semantics) — see `docs/engineering/dev-environment.md` and the JS controllers themselves, which have no separate unit-test runner. `yarn build` runs first because `bin/rails test:system` on its own skips jsbundling's `javascript:build` Rake hook — a stale `app/assets/builds/application.js` silently masks JS changes and looks exactly like a broken Stimulus controller.
- **rubocop** — house style (`docs/engineering/coding-style.md`).
- **brakeman** — Rails-specific static security analysis (SQL injection, XSS, mass assignment, etc.). Run via the gem's own Ruby API (`Brakeman.run(...)`, see `bin/ci`'s source), not the `bin/brakeman` CLI: the CLI performs a self-update version check over the network on every invocation, and that check failing takes the whole scan down with it — a tooling flake unrelated to any app code, hit repeatedly enough in CI to be worth routing around locally too.
- **bundler-audit / yarn audit** — known-CVE scanning for the Ruby and JS dependency trees respectively. Non-blocking (⚠️, not ❌): an advisory here can be a pre-existing upstream issue with no fixed release yet (see below), not something this branch introduced or can single-handedly resolve. It's still always shown, never silently swallowed.

## Reading an advisory

`bin/ci` doesn't try to distinguish "this branch introduced a new advisory" from "this advisory already existed on `main`" — that distinction has mattered in practice (a security scan job failing on an unrelated PR because of an upstream gem with no fix yet is a real, recurring shape of false alarm here, not a hypothetical). When `bin/ci` reports one:

```sh
git stash                 # or: git worktree add, git checkout main --
bin/bundler-audit check   # or: yarn audit
git stash pop
```

If the same advisory shows up on `main` independent of your change, it's not this branch's problem to fix — note it and move on. If it's new, it is.

## What "every PR" means in practice

Blocking, every time, no exceptions: `bin/ci` full run green (or every ❌ explained and fixed), including a genuine PASS — not a stale cached one — right before the `--no-ff` merge.

For a **new regression test** (one written specifically to lock in a bug fix, not a pre-existing test being reused), also do a one-time discrimination check: temporarily revert the fix, confirm the new test actually fails, then restore the fix and confirm it passes again. This is not part of `bin/ci` — it requires knowing which specific change to revert, so it can't be automated generically — but it has caught real bugs in this project's own test suite (a stale JS bundle masking a broken fix; a test comparing two different controller instances by construction; assertions that happened to pass against both the buggy and fixed code). Do it once per new test, not on every `bin/ci` run.

## Open-source-specific coverage

Beyond the day-to-day suite above, a public repository carries obligations the tests above don't cover on their own:

- **License compliance** — `THIRD-PARTY-LICENSES.md` lists every non-MIT bundled component. Re-check it whenever a new runtime dependency (Ruby gem or JS package) is added: `bundle licenses` / `yarn licenses list` show what's actually in the tree; anything not MIT/BSD/Apache-2.0/OFL needs the same review a new font or library got during the v0.1 license audit (see `docs/product/roadmap.md`'s v0.1 section) before it ships. Not automated as a blocking check — a license change needs a human judgment call, not a pass/fail gate — but worth running after any dependency-adding PR.
- **Secret scanning** — nothing in `bin/ci` greps for committed credentials today. Before a first public push (and periodically after), run something like:
  ```sh
  git log -p | grep -inE "(api[_-]?key|secret|password|token)\s*[:=]\s*['\"][A-Za-z0-9/+_-]{16,}"
  ```
  across the full history, not just the working tree — a fresh public repo means the entire history is visible from day one (see `docs/engineering/release-process.md`).
- **`bin/bundler-audit`/`yarn audit` already double as dependency-supply-chain checks** — the main thing a solo/small-team OSS project actually needs here (no dedicated SCA tool currently in the toolchain).

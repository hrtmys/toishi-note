# CLAUDE.md

Instructions for Claude Code (or any AI agent) working in this repository. Read `docs/README.md` for the full documentation index — this file is only the things worth repeating at the start of every session.

## Verification: use `bin/ci`, not individual tools

This repo has a single entry point for "is this branch good to merge": `bin/ci` (full mode by default; `bin/ci quick` skips system tests for fast local iteration only). It runs the same gauntlet every PR here goes through — `yarn build`, `bin/rails test`, `bin/rails test:system`, RuboCop, Brakeman, `bundler-audit`, `yarn audit` — and prints one compact line per step instead of each tool's full output.

**Do not run `bin/rails test`, `bin/rails test:system`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, or `yarn audit` as separate tool calls and read each one's full output.** That reconstructs exactly what `bin/ci` already does, at many times the context cost, for output that's almost always "this passed." Use the `verify` skill (`.claude/skills/verify/SKILL.md`) or just run `bin/ci` directly — see `docs/engineering/verification.md` for what each step means and how to read a failure.

Practical notes carried over from hard-won experience in this repo:
- `bin/ci full` takes several minutes, mostly `test:system`. Run it via Bash with `run_in_background: true`, then wait for the completion notification rather than polling every 60-120s — each poll that re-enters the conversation costs a full turn for no new information.
- A non-zero `bundler-audit`/`yarn audit` result is reported as a non-blocking advisory (⚠️), not a failure — it can be a pre-existing upstream CVE with no fixed release yet. Check whether it also appears on `main` before treating it as this branch's problem (see `docs/engineering/verification.md`).
- For a genuinely new regression test, do a one-time discrimination check by hand (revert the fix, confirm the test fails, restore it, confirm it passes) — this isn't something `bin/ci` can automate, since it requires knowing which change to revert.

### Verifying several branches at once

When several independent feature branches are in flight together (e.g. multiple subagents each fixing a different issue), **do not** run `bin/d bin/ci` locally in more than one worktree at the same time. The containers contend for CPU, and `bundler-audit`'s `ruby-advisory-db` git clone in particular has been observed to hang for 30+ minutes under concurrent load on this host (confirmed via `docker top` showing the clone itself stuck, not just slow) — every one of several simultaneous runs can end up wedged on that single step, wasting far more wall-clock time than running them one at a time would have.

Push each branch and open its PR, then rely on GitHub Actions (`gh pr checks <PR#>`, or `gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs --allow-escape-sequences` for a failure's log) for verification — the cloud runners aren't affected by local resource contention and already run each PR's checks in true parallel. Reach for a local `bin/d bin/ci` run only when you need to verify a *combined* result before a final integration merge (e.g. merging several of these branches together first to catch cross-branch interaction issues) — and even then, run it once against the merged result, not once per branch.

## Working conventions

- Conventional Commits, feature branch per PR, `--no-ff` merges only — see `docs/engineering/git-workflow.md`.
- English comments only in code; explicit `locals:` in partials; `Current.user`-scoped queries only, never a bare `Model.find` — see `docs/engineering/coding-style.md`.
- No CDN-loaded assets, no unnecessary frontend framework/editor dependency (this has come up repeatedly: no CodeMirror/EasyMDE) — see `docs/engineering/asset-strategy.md`.
- Server-authoritative state; no public JSON API — HTML/Turbo-frame endpoints only, even for JS-driven UI.

# CLAUDE.md

Instructions for Claude Code (or any AI agent) working in this repository. Read `docs/README.md` for the full documentation index — this file is only the things worth repeating at the start of every session.

## Verification: use `bin/ci`, not individual tools

This repo has a single entry point for "is this branch good to merge": `bin/ci` (full mode by default; `bin/ci quick` skips system tests for fast local iteration only). It runs the same gauntlet every PR here goes through — `yarn build`, `bin/rails test`, `bin/rails test:system`, RuboCop, Brakeman, `bundler-audit`, `yarn audit` — and prints one compact line per step instead of each tool's full output.

**Do not run `bin/rails test`, `bin/rails test:system`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, or `yarn audit` as separate tool calls and read each one's full output.** That reconstructs exactly what `bin/ci` already does, at many times the context cost, for output that's almost always "this passed." Use the `verify` skill (`.claude/skills/verify/SKILL.md`) or just run `bin/ci` directly — see `docs/engineering/verification.md` for what each step means and how to read a failure.

Practical notes carried over from hard-won experience in this repo:
- `bin/ci full` takes several minutes, mostly `test:system`. Run it via Bash with `run_in_background: true`, then wait for the completion notification rather than polling every 60-120s — each poll that re-enters the conversation costs a full turn for no new information.
- A non-zero `bundler-audit`/`yarn audit` result is reported as a non-blocking advisory (⚠️), not a failure — it can be a pre-existing upstream CVE with no fixed release yet. Check whether it also appears on `main` before treating it as this branch's problem (see `docs/engineering/verification.md`).
- For a genuinely new regression test, do a one-time discrimination check by hand (revert the fix, confirm the test fails, restore it, confirm it passes) — this isn't something `bin/ci` can automate, since it requires knowing which change to revert.

## Working conventions

- Conventional Commits, feature branch per PR, `--no-ff` merges only — see `docs/engineering/git-workflow.md`.
- English comments only in code; explicit `locals:` in partials; `Current.user`-scoped queries only, never a bare `Model.find` — see `docs/engineering/coding-style.md`.
- No CDN-loaded assets, no unnecessary frontend framework/editor dependency (this has come up repeatedly: no CodeMirror/EasyMDE) — see `docs/engineering/asset-strategy.md`.
- Server-authoritative state; no public JSON API — HTML/Turbo-frame endpoints only, even for JS-driven UI.

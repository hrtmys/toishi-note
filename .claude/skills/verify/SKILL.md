---
name: verify
description: Run this project's full pre-merge verification (tests, lint, security scans) via bin/ci in one shot, instead of running rails test, rails test:system, rubocop, brakeman, and bundler-audit as separate tool calls. Use before merging any PR in this repo, or whenever asked to "verify", "run CI", or "run the tests" here.
---

# Verify

This repo has a single entry point for "is this branch good to merge": `bin/ci`. It runs `yarn build`, `bin/rails test`, `bin/rails test:system`, RuboCop, Brakeman, `bundler-audit`, and `yarn audit` — the same gauntlet every PR in this project's history has gone through — and prints one line per step instead of each tool's full output. See `docs/engineering/verification.md` for why each step exists and what counts as blocking vs. advisory.

**Do not reconstruct this gauntlet by hand.** Do not run `bin/rails test`, `bin/rails test:system`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, or `yarn audit` as separate tool calls and read each one's full output — that is the exact pattern this skill exists to replace, and it burns a conversation's context on output that is 99% "this passed" noise. One `bin/ci` call gives the same information in a fraction of the tokens.

## How to run it

```sh
bin/ci          # full — required before merging. Takes several minutes, mostly test:system.
bin/ci quick    # skips test:system and yarn audit — fast local iteration only, never a merge gate
```

`bin/ci full` typically takes 3-6 minutes. **Run it via Bash with `run_in_background: true`**, then wait for the completion notification (or one `ScheduleWakeup`/poll at a generous delay — 200-300s, not 60s). Do not poll every 60-120 seconds in a loop; each check-in that re-enters the conversation costs a full turn, and this run does not need babysitting more often than that. This mirrors a mistake actually made in this project's history: polling a single ~150s system-test run seven or eight times in a row at 60-180s intervals, most of which reported nothing had changed.

## Reading the output

Read only the summary block `bin/ci` prints — do not separately `Read` any file under `tmp/ci_logs/` unless a step shows ❌ (or you want to double check a ⚠️). The summary line for that failing step names the log file to read; that log has the *full*, unfiltered output of the underlying tool, so there's no information lost by not reading it for the steps that passed.

- `✅` — passed, nothing further to do.
- `⚠️` — a non-blocking advisory (currently only `bundler-audit`/`yarn audit`, which can be pre-existing upstream CVEs with no fix released yet — see `docs/engineering/verification.md`'s "Reading an advisory" section for how to tell whether it's new to this branch). Worth a one-line mention to the user, not a blocker.
- `❌` — blocking failure. `bin/ci` already extracts just the failing test names (for `rails test`/`rails test:system`) or the log's last 15 lines (for everything else) inline in its own output — start there before opening the full log.

## After fixing a failure

Re-run `bin/ci` (or `bin/ci quick` for a fast check while iterating, but always `bin/ci` full before the actual merge) rather than re-running only the one tool that failed — a fix for one step occasionally breaks another (e.g. a RuboCop autofix that changes behavior a test then catches), and the full run is cheap to re-trigger in the background while doing other work.

## What this skill does NOT cover

- **New regression tests.** A test written specifically to lock in a bug fix should be proven to actually discriminate: temporarily revert the fix, confirm the new test fails, restore the fix, confirm it passes again. This requires knowing which specific change to revert, so it isn't automated by `bin/ci` — do it by hand, once, right after writing such a test. See `docs/engineering/verification.md` for real examples of tests that didn't discriminate on the first attempt.
- **License/secret-scanning checks.** Not run on every `bin/ci` invocation (they don't change often enough to justify the cost on every run) — see `docs/engineering/verification.md`'s "Open-source-specific coverage" section for when and how to run these.

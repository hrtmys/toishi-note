---
title: Dev Environment (bin/d) Design Notes
description: Why the Docker dev setup looks the way it does, recorded as the change happens
status: living
updated: 2026-09-07
---

# Dev environment (`bin/d`) design notes

Records the "why" behind [`Dockerfile.dev`](../../Dockerfile.dev) and [`bin/d`](../../bin/d). Updated alongside every change to them — backfilling docs after the fact is painful, so we write them as we go.

**Used to be a VS Code devcontainer** (`.devcontainer/`, image `mcr.microsoft.com/devcontainers/ruby:4`). Dropped in favor of a plain `docker build`/`docker run` wrapper: no editor tie-in, one Dockerfile shared with nothing else editor-specific to keep in sync, and it doesn't depend on VS Code's Dev Containers extension staying up (or the editor itself staying up — the devcontainer closing/restarting along with a crashed VS Code was the immediate trigger for the switch). `bin/d` mirrors the pattern already used in this author's other Rails project (`runsheet`'s `bin/d`), just extended with Node/Yarn and a browser since this app needs both, not just Ruby.

## How `bin/d` works

`bin/d some-command args...` runs `some-command args...` inside a container built from `Dockerfile.dev`, with the repo bind-mounted at `/rails` and the container's uid/gid set to match the host user (`docker run -u "$(id -u):$(id -g)"`) — so anything the container writes (gems, `node_modules`, logs, the SQLite files under `storage/`) stays owned by the host user, not root. There's no daemon, no `docker compose up` to remember to leave running — every invocation is a fresh `--rm` container.

- **Image rebuilds are automatic and correctly-timed.** `bin/d` hashes `Dockerfile.dev` and compares it against a label baked into the last built image (`toishi-note.dockerfile=<hash>`); a stale image (missing a package someone just added) rebuilds itself on the next invocation instead of silently staying stale. Docker's own build cache means an unchanged `Dockerfile.dev` costs nothing per invocation — this check only guards against the file *having* changed.
- **Gems and node modules persist on the host**, not in the throwaway container — `vendor/bundle` and `node_modules` are bind-mounted (both already gitignored), so `bundle install`/`yarn install` only happens once per dependency change, not once per container.
- **`HOME` points inside the repo** (`tmp/dockerhome`, gitignored) rather than the container user's real home, since the container has no real home directory for an arbitrary host uid — this is exactly the same trick `runsheet`'s `bin/d` uses.
- **The port only publishes for server-shaped commands** (`*server*`/`*dev*`/`*puma*` in the invoked command) — every other command (`bin/rails test`, `bin/rubocop`, a one-off console) doesn't need `-p 3000:3000`, and publishing it unconditionally would make two concurrent `bin/d` invocations collide over the port for no reason.

## System packages the base image doesn't include

The base image (`ruby:4.0.4-slim`) is a plain Ruby image with no Node and none of what this app needs beyond that. What `Dockerfile.dev` adds, and why:

- **`libvips42t64`** — `image_processing`/`ruby-vips` (Gemfile) load it via FFI at runtime, not at `bundle install` time. Without it, the app doesn't even boot (`bin/rails` itself fails as soon as it requires `vips`).
- **`chromium` + `chromium-driver`** — `bin/rails test:system` drives headless Chrome (see [`test/application_system_test_case.rb`](../../test/application_system_test_case.rb)). CI gets a browser for free from the GitHub-hosted runner image; this image doesn't, so `Dockerfile.dev` installs one explicitly. `chromium-driver` provides `chromedriver` on `PATH`, which Selenium's Selenium Manager picks up automatically — no extra Capybara config needed.
- **Node, via `node-build`** — the same install method [the production `Dockerfile`](../../Dockerfile) uses, rather than a second Node-install mechanism (nodenv/nvm/apt's older packaged Node) to keep track of. Pinned to the same version as [`.node-version`](../../.node-version).
- **`build-essential`/`libyaml-dev`/`pkg-config`/`python-is-python3`** — needed to build native gems, mirroring the production `Dockerfile`'s build stage.
- **`foreman`** (a system gem, installed directly in the image rather than via `bundle install`) — `bin/dev` (`Procfile.dev`) shells out to it, and it isn't one of this app's actual dependencies.

`node-gyp` is also installed to mirror what [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) installs, so the image and CI don't drift apart.

## Fonts for Japanese rendering

Two separate gaps, both invisible until something renders Japanese text in this container's headless Chrome:

- **No CJK glyphs at all.** The base image has zero Japanese font coverage, so any Japanese text — in a system test, or in a screenshot taken for the docs site — renders as tofu boxes. `fonts-noto-cjk` fixes this generically and is installed alongside the other apt packages above.
- **None of the three recommended fonts are installed, but the app's CSS asks for them by name first.** `$cjk-monospace-stack` in [`_typography.scss`](../../app/assets/stylesheets/_typography.scss) lists three yuru7 fonts — Bizin Gothic, UDEV Gothic, HackGen — before its other fallbacks, all for the same 1:2 half/full-width ratio: real help in an editor holding mixed Japanese and code. **The app does not bundle any of them.** Shipping multi-MB font files to be downloaded on every fresh visit isn't worth it for fonts that already degrade gracefully to the next name in the stack when they're absent — see [`asset-strategy.md`](asset-strategy.md) for why the runtime path stays that disciplined. Instead, `Dockerfile.dev`'s `install_yuru7_font` helper downloads each directly from its upstream GitHub release (all SIL OFL-1.1) into `/usr/local/share/fonts/<name>/` at image build time — the same thing a contributor or end user installing one locally would do by hand, just automated and baked into the image so its own headless Chromium matches what the project actually recommends. Only the plain Regular/Bold weights are pulled, not each project's Console/35/NF/JPDOC variants.

If you rebuild the container and want to confirm the font actually resolved (not silently fell back), check the computed style in a real page rather than trusting the CSS alone:

```js
getComputedStyle(document.querySelector('textarea')).fontFamily
// => '"Bizin Gothic", "BIZ UDGothic", ...' only proves it was *requested*
Array.from(document.fonts).some(f => f.family === 'Bizin Gothic' && f.status === 'loaded')
// => true confirms it actually loaded
```

## System test parallelism on CI

`test/test_helper.rb` runs tests in parallel across `:number_of_processors` by default. The old devcontainer had 4 cores and never showed a problem with that; `bin/d`'s container reports whatever the host actually has (`nproc` inside it matches the host, since `docker run` doesn't cap CPU count on its own) — on a 12-core host this reproduced the exact same failure class described below on the very first `bin/d bin/ci` run, just from `:number_of_processors` resolving to 12 instead of 4. `PARALLEL_WORKERS=1 bin/d bin/rails test:system` fixed it immediately (104 runs, 0 failures) — `bin/d` passes `PARALLEL_WORKERS` through to the container for exactly this. GitHub Actions' runner for this (private) repo reports only 2 CPUs, and system tests are the expensive case that default was never really tuned for — each parallel worker boots its own Puma server and headless Chrome instance, and `NoteConflictTest` alone opens two Chrome sessions in a single test to simulate two devices. Two parallel workers, one of them briefly needing two browsers at once, on two real CPUs, regularly exceeded what the machine could deliver inside Capybara's wait budget.

The symptom wasn't a consistently broken test — it was a *different* system test timing out almost every run (a toast that hadn't appeared yet, a field still disabled, a banner that hadn't rendered), which is the signature of resource contention rather than an actual bug: confirmed by pulling the failure from 8 consecutive CI runs and finding 7 different tests failing, never a real exception, always a `Capybara::ElementNotFound`/`assert_selector` timeout on some JS-driven state.

Fix, part 1: `.github/workflows/ci.yml`'s `system-test` job sets `PARALLEL_WORKERS=1`, which `test_helper.rb` reads to override the default just for that run. Local runs and the plain `test` job (which has never shown this) are unaffected — the override only applies when `PARALLEL_WORKERS` is actually set.

**Sequential alone turned out not to be enough.** The first verification run with `PARALLEL_WORKERS=1` still failed — a different test again (`SetupFlowTest`, the second-most-frequent offender in the original 8-run survey), same failure class (a Turbo-redirect wait). That means the worst-case multiplicative contention (N workers × M browsers each) wasn't the whole story — this runner is apparently slow/throttled enough on its own that even one worker occasionally misses a wait budget.

Fix, part 2, first attempt: retry the whole 104-test suite up to 3 times in the CI job itself (a bash loop around `bin/rails test:system`), only failing if every attempt failed. **This made things worse, not better** — every one of 3 attempts in the next verification run still failed, with *more* simultaneous failures per attempt (2, instead of the usual 1) than the original baseline. The reason is structural, not bad luck: retrying the whole suite requires all 104 tests to independently avoid flaking *in the same attempt* — a much harder bar than it looks, since the probability of *some* test flaking climbs with every additional test in the run, even if each individual test's own flake rate is low.

Fix, part 2, actual version: retry only the one test that failed, in place, rather than the whole suite. `test_helper.rb` requires the `minitest-retry` gem (MIT, test group only) and calls `Minitest::Retry.use!(retry_count: 2, classes_to_retry: ["ApplicationSystemTestCase"])`, gated behind `ENV["CI"]` (set automatically by GitHub Actions) so a genuinely broken test still fails immediately and undelayed in every context a developer would actually be reading the output — this container has never reproduced the flake, so there's nothing here for a retry to usefully mask. `classes_to_retry` takes the class name as a string, matched against the failing test's ancestors, which is how this stays scoped to system tests specifically (`rails test` — unit/controller/integration, no browser involved — has never shown this failure).

Verified the retry mechanism itself actually engages, not just trusted the gem's README: a scratch test that deliberately fails on its first attempt and passes on its second confirmed it fails immediately without `CI=true` and retries-then-passes with it, before this was wired into the real CI job.

Not raising `Capybara.default_max_wait_time` again as part of any of this — already bumped once before (5s → 8s) and that didn't hold either. This isn't a fixed amount of latency to wait out; it's occasional and unpredictable, which is exactly the shape of problem a bounded per-test retry is for and a larger fixed wait isn't.

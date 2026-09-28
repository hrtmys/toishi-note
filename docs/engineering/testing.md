---
title: Testing
description: Which level a test belongs at, the system test budget, how tests are written, and how to bisect a failed combined PR
status: living
updated: 2026-09-28
---

# Testing

System tests used to be the default here, and CI paid for it: about 130 browser tests, roughly four minutes per run. This page is the rule that replaced that default. Follow it for every new test.

## The rule: the lowest level that can check the behavior

Pick the first level in this table that can observe the behavior. Only fall through when it genuinely can't.

| Behavior | Level | Where |
|---|---|---|
| Validations, scopes, ordering, parsing, anything on a model | Model test | `test/models/` |
| Server-rendered markup, flags, text, order, flash messages, redirects, authorization | Controller/integration test with `assert_select` | `test/controllers/`, `test/integration/` |
| A decision a Stimulus controller makes (what to insert, which key does what, what to sort, whether to restore) | `node:test` unit test of a pure function | `app/javascript/lib/`, tested in `test/javascript/` |
| Something only a real browser can do (list below) | System smoke test | `test/system/` |

### What counts as browser-only

- Real layout, scroll positions and viewport sizes.
- Clipboard, paste, drop, and the `execCommand`/undo plumbing.
- Focus and keyboard flows across async Bootstrap or Turbo events.
- IME composition-event wiring.
- Events passed between Stimulus controllers through the DOM.
- Client rendering after a Turbo-stream insert.
- Whether a script actually executed (XSS) and browser CSP enforcement.
- Two sessions editing at once.
- Chrome installability.

Not browser-only, even if the old suite tested it in a browser: server-rendered markup, flags, text, order, flash messages, redirects, and any decision a controller makes that can be pulled out into a function.

### The extraction pattern

When a Stimulus controller both touches the DOM and decides something, split it. The controller keeps the DOM work (reading values, listening to events, writing results back). The decision moves to a pure function in `app/javascript/lib/` that takes plain values and returns plain values, and gets a `node:test` file in `test/javascript/`. The editor's text edits are the model to copy: the function takes the text and selection, returns the new text and selection, and the controller only applies it.

## The smoke set

The target is one system test per file, each named for the browser-only behavior it guards, with its phases separated by one-line comments. Some of these files already exist and are being rewritten into this shape; the list is the end state.

| File | Browser-only because |
|---|---|
| `note_conflict_test.rb` | two real sessions; a live 409 turns into a banner; `confirm()`; resubmits settle through events |
| `organize_test.rb` | `window.prompt`; real SortableJS drag gestures |
| `command_palette_test.rb` | global shortcut; focus after an async Bootstrap `shown`; hide during the fade; Turbo frame `aria-busy` |
| `editor_preview_test.rb` | CSS visibility; lazy chunk loading; SVG render race; real scroll geometry |
| `security_test.rb` | whether a script actually ran; browser CSP enforcement |
| `textarea_editing_test.rb` | real keystrokes; `execCommand`/undo; composition events on two fields |
| `clipboard_paste_test.rb` | `ClipboardEvent`/`DataTransfer`/`DragEvent`; handler order across controllers; upload round trip |
| `navigation_test.rb` | Turbo Drive lifecycle; `localStorage` restore; Chrome installability over CDP |
| `responsive_layouts_test.rb` | viewport size and the offcanvas sidebar |
| `sidebar_panes_test.rb` | CSS flex layout geometry |
| `sidebar_scroll_test.rb` | `scrollIntoView`/`scrollTop` geometry; client-side sort in the DOM |
| `settings_and_fab_test.rb` | live toggles without reload; reload timing; clipboard API; modal events across controllers; JS translations |
| `todo_note_test.rb` | Turbo submit lifecycle; live modal preview; clipboard; submit-on-change stream |
| `scrap_note_test.rb` | rendering after a Turbo-stream insert; height measured after render; change-then-fetch; clipboard |
| `setup_flow_test.rb` | live field toggling, and HTML5 `required` blocking submission |

## The budget

System tests have a time budget, and CI enforces it. The numbers live in one place, [`test/system_budget.yml`](../../test/system_budget.yml); read them there, since any copy here would drift.

- **What is measured.** Two things: the whole CI system-test job (setup included, since that's what a contributor waits for), and the system-test step alone, on CI and locally. The step thresholds are the job tiers minus the measured setup time; the local ones are the CI ones scaled for a slower machine.
- **Tiers.** The job has an ideal line, then notice, warn, and fail. The CI test step has notice, warn, and fail. Local runs have notice and warn only: **a local run never fails on the budget**, because contributor machines vary too much. CI is the only arbiter.
- **Enforcement.** `enforcement: fail` in the same file makes CI fail the system-test job past the fail tiers, and `system-test` is a required check on `master`. Local runs never fail on budget. Setting it back to `warn` (CI then reports `OVER (not enforced)`) is a deliberate change of its own.
- **Where it shows up.** With `SYSTEM_BUDGET=1` (which `bin/ci` and CI set), the run prints a `System test budget` line with the total and status, plus the slowest tests. `bin/ci` adds that to the system-test summary line and shows ⚠️ for NOTICE, WARN or OVER. On CI, `bin/ci-job-report` applies the job tiers to the whole job and posts GitHub annotations.
- **Retries count.** CI retries a failed system test (see `test/test_helper.rb`); retry time is part of the total, so a flaky test is also a slow test.
- **Memory** is sampled on CI and reported, but not gated.

### Adding a system test

A new system test has to pay for itself. Either the same PR removes or speeds up another system test by at least as much, or the budget is raised first in a separate PR. First check that the behavior really is browser-only (above); most proposals turn out to be integration or `node:test` tests.

### Changing the budget

Any change to `test/system_budget.yml` is its own PR, with fresh CI measurements (several runs, not one) in the description. Never change it inside a feature PR.

To re-measure, read the timings from the `System test budget` line and the `bin/ci-job-report` output on a few recent CI runs of `master`, and compare the job total against the tiers.

## Writing a test

1. **Spec first.** Derive the expected behavior from the [roadmap](../product/roadmap.md), the CHANGELOG, [ux-roadmap.md.old](../product/ux-roadmap.md.old), and the locale files, not from what the code does today. When nothing pins the behavior down, ask the maintainer instead of encoding the current output.
2. **Adversarial.** Go through the cases the spec implies, not just the happy path:
   - boundaries (exactly at a limit, one past it);
   - Japanese text, IME input, surrogate pairs;
   - empty and whitespace-only input;
   - malicious HTML, `javascript:` URLs, SQL-shaped parameters;
   - another user's data;
   - concurrent edits.
3. **Fixed values, never random ones**, so a failure reproduces.
4. **One mutation check when you write it.** Deliberately break the production behavior the test guards, confirm the test fails on the assertion you expect, then revert. For system tests, rebuild assets (`bin/d yarn build`) before the run, or you're testing the old bundle. Record the mutation in the PR description.
5. **No fixed sleeps in system tests.** Wait with `wait_until` or Capybara matchers. The only exceptions are the paced drag gestures in the organize test and negative windows that must outlast a known debounce (the IME test waits past the autosave debounce).
6. **Toasts** are asserted per phase through the shared system-test helpers (being added with the smoke set), so an earlier toast can't satisfy or break a later assertion.

## Running tests

- `bin/ci` runs everything, system tests serially. See [verification.md](verification.md).
- Scoped: `bin/d bin/rails test <files>` for Ruby tests, `bin/d yarn test:js` for the JS unit tests.
- System tests are heavy locally. Run them only when you need to, serially (`PARALLEL_WORKERS=1`), and let CI do the full run.

## Bisecting a failed combined PR

When several branches are merged together and the combined result fails, find the culprit locally instead of re-running the whole suite:

1. List the merges: `git log --first-parent --oneline`.
2. Either revert them one at a time (`git revert -m 1 <merge>`), or check out each first-parent commit in turn.
3. Rebuild assets: `bin/d yarn build`.
4. Run only the failing file, serially, with the failing seed: `bin/d env PARALLEL_WORKERS=1 bin/rails test <file> --seed <n>`.

Retries are off locally, so a local failure is real, not flakiness.
